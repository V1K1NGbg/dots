#!/usr/bin/env bash
set -euo pipefail

directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

render() {
    # One streaming awk process handles normalization/resampling; no per-frame
    # subprocesses. Keep 16-bit amplitude detail until AFTER normalization.
    LC_ALL=C awk -v columns="${1:-0}" -v spacing="${2:-0}" '
    BEGIN { split(" ;▁;▂;▃;▄;▅;▆;▇;█", glyph, ";") }
    /^[0-9]+(;[0-9]+)*;?$/ {
        count = split($0, sample, ";")
        if (sample[count] == "") count--
        peak = 0
        for (i = 1; i <= count; i++) if (sample[i] > peak) peak = sample[i]
        # Instant attack and short release: volume drops settle within ~0.5s.
        envelope = peak > envelope * 0.8 ? peak : envelope * 0.8
        if (envelope < 1) envelope = 1
        total = columns > 0 ? columns : count
        text = ""
        for (i = 0; i < total; i++) {
            position = total > 1 ? i * (count - 1) / (total - 1) : 0
            left = int(position) + 1
            right = left < count ? left + 1 : left
            value = sample[left] + (sample[right] - sample[left]) * (position - int(position))
            level = int(value * 8 / envelope + 0.5)
            if (level > 8) level = 8
            # Feather BOTH ends of every edge instead of cutting side surfaces
            # short. Four columns rise from a one-step tip, bringing the ends
            # closer while keeping full-scale peaks out of the corner itself.
            if (columns > 0) {
                edge = i < total - 1 - i ? i : total - 1 - i
                limit = int(8 * (edge + 0.5) / 4)
                if (level > limit) level = limit
            }
            text = text glyph[level + 1]
        }
        if (columns > 0)
            printf "{\"text\":\"<span letter_spacing=\\\"%d\\\">%s</span>\"}\n", spacing, text
        else printf "{\"text\":\"%s\"}\n", text
        fflush()
    }'
}

case "${1:-}" in
    --render) render "${2:-0}" "${3:-0}"; exit ;;
    --stream)
        # Each Waybar surface owns its stream; output hotplug starts/stops it.
        axis=${2:?Expected horizontal or vertical}
        [[ $axis == horizontal || $axis == vertical ]] || exit 2
        length=$(hyprctl -j monitors | jq -er --arg output "${WAYBAR_OUTPUT_NAME:-}" \
            --arg axis "$axis" '
            [.[] | select(.name == $output) |
              (if (.transform % 2) == 1 then [.height, .width]
               else [.width, .height] end) as $size |
              (.reserved // [0,0,0,0]) as $reserved |
              (($size[if $axis == "horizontal" then 0 else 1 end] / .scale) -
                (if $axis == "horizontal" then $reserved[0] + $reserved[2]
                 else $reserved[1] + $reserved[3] end) | floor)][0]')
        config=$(mktemp "${XDG_RUNTIME_DIR:?}/dots-visualizer-cava.XXXXXXXX")
        trap 'rm -f -- "$config" "$config.metrics"' EXIT
        trap 'exit 0' TERM INT
        LC_ALL=C.UTF-8 pango-view --no-display --pixels --font 'monospace 11' \
            --text '██████████' --margin 0 --serialize-to "$config.metrics"
        advance=$(jq -er '.output.width / 10 | floor | select(. > 0)' "$config.metrics")
        # Give columns a 1px separation, then distribute the remainder so the
        # complete spectrum still reaches both ends of the available edge.
        column_gap=1024
        columns=$(((length * 1024 + column_gap) / (advance + column_gap)))
        ((columns >= 2)) || exit 1
        spacing=$(((length * 1024 - columns * advance) / (columns - 1)))
        cp "$directory/visualizer-cava.conf" "$config"
        cava -p "$config" | render "$columns" "$spacing"
        exit ;;
    --build)
        cache=${XDG_CACHE_HOME:-$HOME/.cache}/dots-visualizer
        mkdir -p "$cache"
        exec 8>"$cache/build.lock"
        flock 8
        binary=$cache/renderer
        if [[ ! -x $binary || $directory/visualizer-renderer.c -nt $binary ]]; then
            temporary=$(mktemp "$cache/renderer.XXXXXXXX")
            trap 'rm -f -- "$temporary"' EXIT
            read -r -a flags <<< "$(pkg-config --cflags --libs gtk+-3.0 gtk-layer-shell-0)"
            clang -O2 -Wall -Wextra -Werror "$directory/visualizer-renderer.c" \
                -o "$temporary" "${flags[@]}" -lm
            chmod 0755 "$temporary"
            mv -f "$temporary" "$binary"
        fi
        printf '%s\n' "$binary"
        exit ;;
    --run)
        if [[ ${DOTS_VISUALIZER_RENDERER:-smooth} == bars ]]; then
            exec bash "$0" --run-bars
        fi
        binary=$(bash "$0" --build)
        # The service owns the entire pipeline, including the one shared capture.
        cava -p "$directory/visualizer-cava.conf" | "$binary"
        exit ;;
    --run-bars)
        for command in waybar cava hyprctl jq pango-view awk; do
            if ! command -v "$command" >/dev/null; then
                notify-send 'Audio visualizer unavailable' "Missing dependency: $command" || true
                exit 1
            fi
        done
        exec waybar --config "$directory/visualizer-waybar.json" \
            --style "$directory/visualizer.css" ;;
    '') ;;
    *) printf 'Usage: %s [--run|--run-bars|--build|--stream horizontal|--stream vertical|--render]\n' "$0" >&2; exit 2 ;;
esac

# Serialize presses, including while systemd is starting/stopping the process.
exec 9>"${XDG_RUNTIME_DIR:?}/dots-visualizer-toggle.lock"
flock 9
unit=dots-visualizer.service
state=$(systemctl --user show "$unit" --property=ActiveState --value)
case "$state" in
    active|activating|reloading) systemctl --user stop "$unit" ;;
    *)
        systemctl --user import-environment WAYLAND_DISPLAY
        if ! systemctl --user start "$unit"; then
            notify-send 'Audio visualizer failed to start' \
                'See journalctl --user -u dots-visualizer.service for details.' || true
            exit 1
        fi
        ;;
esac

#!/usr/bin/env bash
# Offline checks. Desktop rendering and real process cleanup need the laptop.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script=$root/.config/hypr/visualizer.sh
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
mkdir "$scratch/bin"
export XDG_RUNTIME_DIR=$scratch EVENT_LOG=$scratch/events
export PATH="$scratch/bin:$PATH" WAYLAND_DISPLAY=wayland-test

cat > "$scratch/bin/systemctl" <<'SH'
#!/usr/bin/env bash
case "$2" in
    show) echo "$TEST_STATE" ;;
    import-environment) echo import >> "$EVENT_LOG" ;;
    start) echo start >> "$EVENT_LOG"; exit "${TEST_FAIL:-0}" ;;
    stop) echo stop >> "$EVENT_LOG" ;;
    *) exit 99 ;;
esac
SH
cat > "$scratch/bin/flock" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$scratch/bin/notify-send" <<'SH'
#!/usr/bin/env bash
echo notify >> "$EVENT_LOG"
SH
cat > "$scratch/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' '[{"name":"test","width":1920,"height":1080,"scale":1.5,"transform":1}]'
SH
cat > "$scratch/bin/cava" <<'SH'
#!/usr/bin/env bash
[[ $1 == -p && -f $2 ]]
sed -n '/^bars = /p' "$2" >> "$EVENT_LOG"
printf '0;1;2;3;4;5;6;7;8;\n'
SH
cat > "$scratch/bin/waybar" <<'SH'
#!/usr/bin/env bash
[[ $1 == --config && -f $2 && $3 == --style && -f $4 ]]
echo waybar >> "$EVENT_LOG"
SH
cat > "$scratch/bin/pango-view" <<'SH'
#!/usr/bin/env bash
printf '%s\n' '{"output":{"width":71680}}' > "${@: -1}"
SH
chmod +x "$scratch/bin/"*

printf '0;1;2;3;4;5;6;7;8;\n0;0;\n9;invalid;$(bad);8;\n' |
    bash "$script" --render > "$scratch/frames"
jq -se 'map(.text) == [" ▁▂▃▄▅▆▇█", "  "]' "$scratch/frames" >/dev/null
# Proportional audio levels produce identical spectra, including very quiet
# input. A volume drop converges without restarting; silence stays blank.
for multiplier in 1 10 1000; do
    printf '0;%s;%s;%s;\n' "$multiplier" "$((multiplier * 2))" "$((multiplier * 4))" |
        bash "$script" --render > "$scratch/normalized-$multiplier"
done
cmp "$scratch/normalized-1" "$scratch/normalized-10"
cmp "$scratch/normalized-1" "$scratch/normalized-1000"
{
    printf '0;1000;2000;4000;\n'
    for ((frame=0; frame<40; frame++)); do printf '0;1;2;4;\n'; done
    printf '0;0;0;0;\n'
} | bash "$script" --render > "$scratch/release"
jq -se '.[0].text == .[-2].text and .[-1].text == "    "' "$scratch/release" >/dev/null

for state in active activating reloading inactive failed; do
    : > "$EVENT_LOG"
    TEST_STATE=$state bash "$script"
    case $state in
        active|activating|reloading) [[ $(cat "$EVENT_LOG") == stop ]] ;;
        *) [[ $(cat "$EVENT_LOG") == $'import\nstart' ]] ;;
    esac
done
: > "$EVENT_LOG"
if TEST_STATE=failed TEST_FAIL=1 bash "$script"; then
    echo 'Expected service failure' >&2; exit 1
fi
[[ $(cat "$EVENT_LOG") == $'import\nstart\nnotify' ]]

for axis in horizontal vertical; do
    : > "$EVENT_LOG"
    WAYBAR_OUTPUT_NAME=test bash "$script" --stream "$axis" > "$scratch/frames"
    expected=90
    [[ $axis != vertical ]] || expected=160
    [[ $(cat "$EVENT_LOG") == "bars = 64" ]]
    jq -e --argjson columns "$expected" '(.text | gsub("<[^>]*>"; "") | length) == $columns' "$scratch/frames" >/dev/null
done
[[ -z $(find "$scratch" -name 'dots-visualizer-cava.*' -print) ]]
printf '65535;65535;\n' | bash "$script" --render 20 0 |
    jq -e '(.text | gsub("<[^>]*>"; "")) == "▁▃▅▇████████████▇▅▃▁"' >/dev/null
: > "$EVENT_LOG"
bash "$script" --run-bars
[[ $(cat "$EVENT_LOG") == waybar ]]
jq -e 'length == 4 and
    (map(.position) | sort == ["bottom","left","right","top"]) and
    all(.[]; .layer == "bottom" and .exclusive == false and .passthrough == true
        and ."on-sigusr1" == "noop" and ."on-sigusr2" == "noop"
        and ((.height // .width) == 16)
        and ."custom/spectrum"."return-type" == "json")' \
    "$root/.config/hypr/visualizer-waybar.json" >/dev/null
bash -n "$script" "$root/install.sh"
echo 'Visualizer Bash frame, scaled/rotated output sizing, config and mocked toggle checks passed'

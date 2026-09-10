#!/usr/bin/env bash
# Run on the laptop after deployment, with music playing. Leaves visualizer on.
set -euo pipefail
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(hyprctl instances -j | jq -er '.[0].instance')}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-$(hyprctl instances -j | jq -er '.[0].wl_socket')}
scratch=$(mktemp -d "$XDG_RUNTIME_DIR/dots-visualizer-check.XXXXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
unit=dots-visualizer.service
toggle=$HOME/.config/hypr/visualizer.sh
binary=$(bash "$toggle" --build)
"$binary" --self-test
hyprctl binds -j | jq -e 'any(.[]; .key == "G" and .modmask == 64 and
    .description == "Toggle edge audio visualizer")' >/dev/null
hyprctl monitors -j | jq 'map({name,reserved})' > "$scratch/reserved"
hyprctl activewindow -j | jq -r '.address' > "$scratch/focus"
for cycle in 1 2 3; do
    if ! systemctl --user is-active --quiet "$unit"; then bash "$toggle"; fi
    sleep 1
    bash "$toggle"
    [[ $(systemctl --user show "$unit" -p ActiveState --value) == inactive ]]
    ! pgrep -u "$UID" -f "^cava -p $XDG_RUNTIME_DIR/dots-visualizer-cava\."
    ! pgrep -u "$UID" -f "^cava -p $HOME/.config/hypr/visualizer-cava[.]conf$"
    hyprctl layers -j | jq -e '[.. | objects | select(.namespace? == "dots-visualizer")] | length == 0' >/dev/null
done
bash "$toggle"
sleep 2
hyprctl layers -j | jq -e 'all(.[]; [.levels["1"][] |
    select(.namespace == "dots-visualizer")] |
    length == 4 and all(.[]; .w == 16 or .h == 16))' >/dev/null
[[ $(pgrep -u "$UID" -f "^cava -p $HOME/.config/hypr/visualizer-cava[.]conf$" | wc -l) -eq 1 ]]
hyprctl monitors -j | jq 'map({name,reserved})' > "$scratch/reserved-after"
cmp "$scratch/reserved" "$scratch/reserved-after"
hyprctl activewindow -j | jq -r '.address' > "$scratch/focus-after"
cmp "$scratch/focus" "$scratch/focus-after"
# A separate short sample verifies that the real playback monitor delivers
# changing, nonzero frames. It never pauses music or alters sink volume.
status=0
timeout 2 cava -p "$HOME/.config/hypr/visualizer-cava.conf" > "$scratch/audio" || status=$?
[[ $status == 0 || $status == 124 ]]
"$binary" --analyze < "$scratch/audio" > "$scratch/rendered"
jq -se 'length > 5 and any(.[]; .peak > 5)' "$scratch/rendered" >/dev/null
[[ $(sort -u "$scratch/audio" | wc -l) -gt 1 ]]
printf 'PASS: native renderer, Super+G binding, three stop/start cycles, one shared CAVA, capture cleanup, four 16px surfaces per display, unchanged focus/reserved space, changing music frames. Left on.\n'

#!/usr/bin/env bash
# Run from a synced snapshot on the laptop; preserve unrelated active settings.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(hyprctl instances -j | jq -er 'if length == 1 then .[0].instance else error("Expected one Hyprland session") end')}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-$(hyprctl instances -j | jq -er --arg instance "$HYPRLAND_INSTANCE_SIGNATURE" '.[] | select(.instance == $instance) | .wl_socket')}
active=$HOME/.config/hypr/hyprland.lua
binding=$(rg -F '"Toggle edge audio visualizer"' "$root/.config/hypr/hyprland.lua")
[[ -f $active && -n $binding ]]
if rg -q 'mod \.\. " \+ G"' "$active" && ! grep -Fxq "$binding" "$active"; then
    echo 'Super+G already has a different binding; refusing to overwrite it.' >&2
    exit 1
fi
backup=$(mktemp -d "$HOME/dots-dev/visualizer-backup.XXXXXXXX")
files=(.config/hypr/visualizer.sh .config/hypr/visualizer-cava.conf
       .config/hypr/visualizer-renderer.c
       .config/hypr/visualizer-waybar.json .config/hypr/visualizer.css
       .config/systemd/user/dots-visualizer.service)
for relative in .config/hypr/hyprland.lua "${files[@]}"; do
    if [[ -e $HOME/$relative ]]; then
        mkdir -p "$backup/${relative%/*}"
        cp -p "$HOME/$relative" "$backup/$relative"
    else
        printf '%s\n' "$relative" >> "$backup/previously-absent"
    fi
done
for relative in "${files[@]}"; do
    install -D -m 0644 "$root/$relative" "$HOME/$relative"
done
if ! grep -Fxq "$binding" "$active"; then
    printf '\n%s\n' "$binding" >> "$active"
fi
systemctl --user daemon-reload
systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
hyprctl reload
errors=$(hyprctl configerrors)
[[ -z $errors ]] || { printf '%s\nBackup: %s\n' "$errors" "$backup" >&2; exit 1; }
printf 'Visualizer installed (not started). Backup: %s\n' "$backup"

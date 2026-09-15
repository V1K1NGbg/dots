#!/usr/bin/env bash
# Run from a synced snapshot on the laptop; preserve unrelated active settings.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(hyprctl instances -j | jq -er 'if length == 1 then .[0].instance else error("Expected one Hyprland session") end')}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-$(hyprctl instances -j | jq -er --arg instance "$HYPRLAND_INSTANCE_SIGNATURE" '.[] | select(.instance == $instance) | .wl_socket')}
active=$HOME/.config/hypr/hyprland.lua
binding=$(rg -F '"Toggle Miku desktop companion"' "$root/.config/hypr/hyprland.lua")
[[ -f $active && -n $binding ]]
if rg -q 'mod \.\. " \+ SHIFT \+ M"' "$active" && ! grep -Fxq "$binding" "$active"; then
    echo 'Super+Shift+M already has a different binding; refusing to overwrite it.' >&2
    exit 1
fi
bash "$root/scripts/build-miku-renderer.sh"
if systemctl --user is-active --quiet dots-miku.service; then
    systemctl --user stop dots-miku.service
fi
python3 "$root/scripts/setup-miku.py"
mkdir -p "$HOME/dots-dev"
backup=$(mktemp -d "$HOME/dots-dev/miku-backup.XXXXXXXX")
files=(.config/hypr/miku.sh .config/hypr/miku-input.py .config/hypr/miku/overlay.conf
       .config/hypr/miku/actions.xml .config/hypr/miku/behaviors.xml
       .config/hypr/miku/README.md .config/systemd/user/dots-miku.service)
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
printf 'Miku installed (not started). Backup: %s\n' "$backup"

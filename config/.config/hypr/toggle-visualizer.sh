#!/usr/bin/env bash

set -euo pipefail

plugin_path=${HYPRWINWRAP_PLUGIN:?HYPRWINWRAP_PLUGIN is not set}

if systemctl --user is-active --quiet cava-wallpaper.service; then
    systemctl --user stop cava-wallpaper.service
    hyprctl plugin unload "$plugin_path" >/dev/null 2>&1 || true
    notify-send "Cava" "Wallpaper visualizer stopped"
    exit 0
fi

if ! hyprctl plugin list | grep -q "hyprwinwrap"; then
    hyprctl plugin load "$plugin_path"
    # Register Cava with the freshly loaded plugin before its window starts.
    hyprctl reload
    sleep 0.3
fi

systemctl --user start cava-wallpaper.service
notify-send "Cava" "Wallpaper visualizer started"

#!/usr/bin/env bash
# Display picker UI; the Hyprland controller owns profiles and layout changes.
set -uo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

if [[ ${1:-} == --choose ]]; then
    menu_setup
    ROFI+=(-theme-str 'window { width: 620px; } listview { lines: 5; }')
    choose "${2:-Display}" '' list || exit 1
    [[ $CHOICE =~ ^[0-9]+$ ]] || exit 1
    printf '%s\n' "$CHOICE"
else
    exec bash "$ROOT/../hypr/monitors.sh" "$@"
fi

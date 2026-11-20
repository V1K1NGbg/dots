#!/usr/bin/env bash
# Rofi picker for the Hyprland display controller's monitor_choose(); rows arrive
# on stdin and the chosen row index is printed.
set -uo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
menu_setup
ROFI+=(-theme-str 'window { width: 620px; } listview { lines: 6; }')
choose "${1:-Display}" '' list || exit 1
[[ $CHOICE =~ ^[0-9]+$ ]] || exit 1
printf '%s\n' "$CHOICE"

#!/usr/bin/env bash
# Display layout entry point; the Hyprland controller owns profiles and changes.
set -uo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

if [[ ${1:-} == --choose ]]; then
    # Picker invoked by the Hyprland controller's monitor_choose().
    menu_setup
    ROFI+=(-theme-str 'window { width: 620px; } listview { lines: 6; }')
    choose "${2:-Display}" '' list || exit 1
    [[ $CHOICE =~ ^[0-9]+$ ]] || exit 1
    printf '%s\n' "$CHOICE"
elif [[ -z ${ROFI_RETV:-} ]]; then
    # Top-level invocation: launch rofi with this script as the modi.
    exec rofi -no-config -theme "$ROOT/theme.rasi" -i -matching fuzzy -no-sort \
        -modi "monitors:$0" -show monitors
elif [[ ${ROFI_RETV} == 1 ]]; then
    # Rofi forwarded a selection; dispatch the chosen action.
    [[ ${ROFI_INFO:-} == choose ]] && exec bash "$ROOT/../hypr/monitors/monitors.sh"
    exit 1
else
    # Rofi is asking for the menu contents (ROFI_RETV=0).
    printf '\0prompt\x1fDisplays\n'
    printf 'Choose display layout\0info\x1fchoose\n'
fi

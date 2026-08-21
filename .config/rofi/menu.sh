#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

selection=${1:-}
if [[ -z "$selection" ]]; then
    selection=$(
        printf '%s\n' \
            "Calculator" \
            "Clipboard" \
            "Autocorrect" \
            "Media" \
            "Wi-Fi" \
            "Bluetooth" \
            "Power" \
            | rofi -dmenu -p "Utilities"
    ) || exit 0
fi

case "$selection" in
    Calculator)
        exec rofi -modi calc -show calc
        ;;
    Clipboard)
        exec rofi -modi "clipboard:$SCRIPT_DIR/clipboard.sh" -show clipboard
        ;;
    Autocorrect)
        exec rofi -modi "autocorrector:$SCRIPT_DIR/autocorrect.sh" -show autocorrector
        ;;
    Media)
        exec rofi -modi "media:$SCRIPT_DIR/media.sh" -show media
        ;;
    Wi-Fi)
        exec rofi -modi "wifi:$SCRIPT_DIR/wifi.sh" -show wifi
        ;;
    Bluetooth)
        exec rofi -modi "bluetooth:$SCRIPT_DIR/bluetooth.sh" -show bluetooth
        ;;
    Power)
        exec rofi -modi "power:$SCRIPT_DIR/power.sh" -show power
        ;;
esac

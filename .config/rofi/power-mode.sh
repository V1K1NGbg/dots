#!/usr/bin/env bash

set -euo pipefail

if ! command -v powerprofilesctl >/dev/null 2>&1; then
    printf 'Power Profiles Daemon is unavailable\n'
    exit 0
fi

if ! profile_list=$(powerprofilesctl list 2>/dev/null); then
    printf 'Power Profiles Daemon is not responding\n'
    exit 0
fi

available_profiles=$(awk '
    /^[[:space:]*]+[a-z-]+:$/ {
        gsub(/[[:space:]*:]/, "")
        print
    }
' <<<"$profile_list")
active_profile=$(powerprofilesctl get 2>/dev/null || true)

profile_available() {
    grep -Fxq -- "$1" <<<"$available_profiles"
}

show_profile() {
    local profile=$1 label=$2

    if ! profile_available "$profile"; then
        printf '× %s (unavailable)\0info\x1f%s\n' "$label" "$profile"
    elif [[ "$profile" == "$active_profile" ]]; then
        printf '● %s (active)\0active\x1ftrue\x1finfo\x1f%s\n' "$label" "$profile"
    else
        printf '○ %s\0info\x1f%s\n' "$label" "$profile"
    fi
}

if [[ $# -eq 0 ]]; then
    show_profile power-saver "Power Saver"
    show_profile balanced "Balanced"
    show_profile performance "Performance"
    exit 0
fi

selected_profile=${ROFI_INFO:-}
if [[ -z "$selected_profile" ]]; then
    case "$1" in
        *"Power Saver"*) selected_profile=power-saver ;;
        *"Balanced"*) selected_profile=balanced ;;
        *"Performance"*) selected_profile=performance ;;
        *) exit 0 ;;
    esac
fi

if ! profile_available "$selected_profile"; then
    notify-send "Power mode unavailable" "This machine does not expose ${selected_profile}."
    exit 0
fi

if [[ "$selected_profile" != "$active_profile" ]]; then
    if ! error_message=$(powerprofilesctl set "$selected_profile" 2>&1); then
        notify-send "Power mode change failed" "${error_message:-Permission was denied.}"
        exit 0
    fi
fi

case "$selected_profile" in
    power-saver) label="Power Saver" ;;
    balanced) label="Balanced" ;;
    performance) label="Performance" ;;
esac
notify-send "Power mode" "$label is now active."

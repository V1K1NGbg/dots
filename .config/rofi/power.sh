#!/usr/bin/env bash

# Power management functions
get_uptime() {
    local uptime_seconds ignored days hours minutes suffix

    if ! read -r uptime_seconds ignored < /proc/uptime; then
        echo "⏰ Uptime unavailable"
        return
    fi

    uptime_seconds=${uptime_seconds%%.*}
    days=$((uptime_seconds / 86400))
    hours=$(((uptime_seconds % 86400) / 3600))
    minutes=$(((uptime_seconds % 3600) / 60))

    printf '⏰ Up'
    if ((days > 0)); then
        [[ $days -eq 1 ]] && suffix="" || suffix="s"
        printf ' %d day%s' "$days" "$suffix"
    fi
    if ((hours > 0)); then
        [[ $hours -eq 1 ]] && suffix="" || suffix="s"
        printf ' %d hour%s' "$hours" "$suffix"
    fi
    if ((minutes > 0)); then
        [[ $minutes -eq 1 ]] && suffix="" || suffix="s"
        printf ' %d minute%s' "$minutes" "$suffix"
    elif ((days == 0 && hours == 0)); then
        printf ' less than a minute'
    fi
    printf '\n'
}

get_battery_status() {
    local battery capacity status
    for battery in /sys/class/power_supply/BAT*; do
        [[ -d "$battery" ]] || continue
        capacity=$(<"$battery/capacity")
        status=$(<"$battery/status")

        if [[ -n "$capacity" && -n "$status" ]]; then
            local icon="🔋"
            case "$status" in
                "Charging") icon="🔌" ;;
                "Full") icon="🔋" ;;
                "Discharging") 
                    if [[ $capacity -le 20 ]]; then
                        icon="🪫"
                    else
                        icon="🔋"
                    fi
                    ;;
            esac
            echo "$icon Battery: ${capacity}% ($status)"
            return
        fi
    done
}

# If no arguments, show the menu
if [[ $# -eq 0 ]]; then
    get_uptime
    get_battery_status
    echo "---"
    echo "🔒 Lock Screen"
    echo "⏻  Shutdown"
    echo "🔄 Restart"

    exit 0
fi

# Handle menu selection
case "$1" in
    "🔒 Lock Screen")
        pkill rofi
        exec hyprlock
        ;;
    "⏻  Shutdown")
        exec systemctl poweroff
        ;;
    "🔄 Restart")
        exec systemctl reboot
        ;;
    *)
        exit 0
        ;;
esac

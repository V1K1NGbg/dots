#!/bin/bash

# Power management functions
get_uptime() {
    local uptime_info=$(uptime -p)
    echo "⏰ $uptime_info"
}

get_battery_status() {
    # Check if we have a battery
    if [[ -d /sys/class/power_supply/BAT1 ]]; then
        local capacity=$(cat "/sys/class/power_supply/BAT1/capacity" 2>/dev/null)
        local status=$(cat "/sys/class/power_supply/BAT1/status" 2>/dev/null)
        
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
        fi
    fi
}

# If no arguments, show the menu
if [[ $# -eq 0 ]]; then
    echo "$(get_uptime)"
    echo "$(get_battery_status)"
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
        sleep 0.1
        if [[ -n ${WAYLAND_DISPLAY:-} ]] && command -v hyprlock >/dev/null 2>&1; then
            hyprlock &
        else
            ~/i3lock.sh &
        fi
        exit 0
        ;;
    "⏻  Shutdown")
        exec shutdown now
        ;;
    "🔄 Restart")
        exec reboot
        ;;
    *)
        exit 0
        ;;
esac

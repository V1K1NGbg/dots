#!/usr/bin/env bash

if ! command -v bluetoothctl &> /dev/null; then
    echo "bluetoothctl is not installed. Please install the NixOS bluez package"
    exit 1
fi

get_powered() {
    bluetoothctl show | awk '/Powered/ {print $2; exit}'
}

get_bluetooth_status() {
    local bt_status
    bt_status=$(get_powered)
    
    if [[ "$bt_status" == "yes" ]]; then
        echo "🔵 Bluetooth: Enabled"
    else
        echo "⚫ Bluetooth: Disabled"
    fi
}

get_connected_devices() {
    local connected_devices connected_count device_names
    connected_devices=$(bluetoothctl devices Connected)
    connected_count=$(grep -c '^Device ' <<<"$connected_devices")
    
    if [[ $connected_count -gt 0 ]]; then
        device_names=$(cut -d' ' -f3- <<<"$connected_devices" | paste -sd, -)
        device_names=${device_names//,/, }
        echo "📱 Connected devices: $connected_count [$device_names]"
    else
        echo "📱 No devices connected"
    fi
}

get_paired_devices() {
    echo "⬅️ Back"
    echo "---"
    bluetoothctl devices Paired | while read -r _ mac name; do

        if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
            echo "🔗 $name (Connected)"
        else
            echo "📲 $name (Paired)"
        fi
    done
}

if [[ $# -eq 0 ]]; then
    get_bluetooth_status
    get_connected_devices
    echo "---"
    
    bt_status=$(get_powered)
    if [[ "$bt_status" == "yes" ]]; then
        echo "⚫ Turn Bluetooth Off"
        echo "📲 Paired Devices"
    else
        echo "🔵 Turn Bluetooth On"
    fi
    
    exit 0
fi

case "$1" in
    *"Turn Bluetooth Off")
        bluetoothctl power off &>/dev/null
        ;;
    *"Turn Bluetooth On")
        bluetoothctl power on &>/dev/null
        ;;
    *"Paired Devices")
        get_paired_devices
        ;;
    *"Back")
        # Go back to main menu
        exec "$0"
        ;;
    🔗*|📲*)
        if [[ "$1" == 🔗* ]]; then
            action=disconnect
            device_name=${1#🔗 }
            device_name=${device_name% (Connected)}
        else
            action=connect
            device_name=${1#📲 }
            device_name=${device_name% (Paired)}
        fi
        mac=$(bluetoothctl devices Paired | grep -F -- "$device_name" | awk '{print $2}')
        if [[ -n "$mac" ]]; then
            bluetoothctl "$action" "$mac" &>/dev/null
        fi
        ;;
    *)
        exit 0
        ;;
esac

#!/usr/bin/env bash

# Check if bluetoothctl is available
if ! command -v bluetoothctl &> /dev/null; then
    echo "bluetoothctl is not installed. Please install the NixOS bluez package"
    exit 1
fi

# Bluetooth status functions
get_bluetooth_status() {
    local bt_status
    bt_status=$(bluetoothctl show | awk '/Powered/ {print $2; exit}')
    
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
        device_names=$(while read -r line; do
            echo "$line" | cut -d' ' -f3-
        done <<<"$connected_devices" | paste -sd, - | sed 's/,/, /g')
        echo "📱 Connected devices: $connected_count [$device_names]"
    else
        echo "📱 No devices connected"
    fi
}

get_paired_devices() {
    echo "⬅️ Back"
    echo "---"
    bluetoothctl devices Paired | while read -r line; do
        local mac name
        mac=$(awk '{print $2}' <<<"$line")
        name=$(cut -d' ' -f3- <<<"$line")

        # Check if device is connected
        if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
            echo "🔗 $name (Connected)"
        else
            echo "📲 $name (Paired)"
        fi
    done
}

# If no arguments, show the menu
if [[ $# -eq 0 ]]; then
    get_bluetooth_status
    get_connected_devices
    echo "---"
    
    # Bluetooth control options
    bt_status=$(bluetoothctl show | grep "Powered" | awk '{print $2}')
    if [[ "$bt_status" == "yes" ]]; then
        echo "⚫ Turn Bluetooth Off"
        echo "📲 Paired Devices"
    else
        echo "🔵 Turn Bluetooth On"
    fi
    
    exit 0
fi

# Handle menu selection
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
    🔗*)
        # Disconnect a connected device
        device_line=${1#🔗 }
        device_name=${device_line% (Connected)}
        # Find MAC address by name
        mac=$(bluetoothctl devices Paired | grep -F -- "$device_name" | awk '{print $2}')
        if [[ -n "$mac" ]]; then
            bluetoothctl disconnect "$mac" &>/dev/null
        fi
        ;;
    📲*)
        # Connect to a paired device
        device_line=${1#📲 }
        device_name=${device_line% (Paired)}
        # Find MAC address by name
        mac=$(bluetoothctl devices Paired | grep -F -- "$device_name" | awk '{print $2}')
        if [[ -n "$mac" ]]; then
            bluetoothctl connect "$mac" &>/dev/null
        fi
        ;;

    *)
        # If it's a status line, just exit
        exit 0
        ;;
esac

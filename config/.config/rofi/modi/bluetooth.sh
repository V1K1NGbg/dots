#!/usr/bin/env bash
set -o pipefail

if ! command -v bluetoothctl &> /dev/null; then
    echo "bluetoothctl is not installed. Install bluez-utils"
    exit 1
fi

get_powered() {
    bluetoothctl show | awk '$1 == "Powered:" {print $2}'
}

get_bluetooth_status() {
    local bt_status
    bt_status=$(get_powered) || return
    
    if [[ "$bt_status" == "yes" ]]; then
        echo "Bluetooth: Enabled"
    else
        echo "Bluetooth: Disabled"
    fi
}

get_connected_devices() {
    local connected_devices connected_count device_names
    connected_devices=$(bluetoothctl devices Connected) || return
    connected_count=$(grep -c '^Device ' <<<"$connected_devices")
    
    if [[ $connected_count -gt 0 ]]; then
        device_names=$(cut -d' ' -f3- <<<"$connected_devices" | paste -sd, -)
        device_names=${device_names//,/, }
        echo "Connected devices: $connected_count [$device_names]"
    else
        echo "No devices connected"
    fi
}

get_paired_devices() {
    local devices status mac name
    devices=$(bluetoothctl devices Paired) || return
    echo "Back"
    echo "---"
    while read -r _ mac name; do
        [[ -n $mac ]] || continue
        status=$(bluetoothctl info "$mac") || return

        if grep -q "Connected: yes" <<<"$status"; then
            echo "Disconnect: $name (Connected)"
        else
            echo "Connect: $name (Paired)"
        fi
    done <<<"$devices"
}

if [[ $# -eq 0 ]]; then
    get_bluetooth_status || exit
    get_connected_devices || exit
    echo "---"
    
    bt_status=$(get_powered) || exit
    if [[ "$bt_status" == "yes" ]]; then
        echo "Turn Bluetooth Off"
        echo "Paired Devices"
    else
        echo "Turn Bluetooth On"
    fi
    
    exit 0
fi

case "$1" in
    "Turn Bluetooth Off")
        bluetoothctl power off >/dev/null
        ;;
    "Turn Bluetooth On")
        bluetoothctl power on >/dev/null
        ;;
    "Paired Devices")
        get_paired_devices
        ;;
    "Back")
        # Go back to main menu
        exec "$0"
        ;;
    Disconnect:*|Connect:*)
        if [[ "$1" == Disconnect:* ]]; then
            action=disconnect
            device_name=${1#Disconnect: }
            device_name=${device_name% (Connected)}
        else
            action=connect
            device_name=${1#Connect: }
            device_name=${device_name% (Paired)}
        fi
        devices=$(bluetoothctl devices Paired) || exit
        mac=''
        while read -r _ address name; do
            [[ $name == "$device_name" ]] || continue
            [[ -z $mac ]] || { echo 'Several paired devices use this name; give them distinct aliases in Bluetooth settings.' >&2; exit 1; }
            mac=$address
        done <<<"$devices"
        [[ -n $mac ]] || { echo 'The selected paired device no longer exists.' >&2; exit 1; }
        bluetoothctl "$action" "$mac" >/dev/null
        ;;
    *)
        exit 0
        ;;
esac

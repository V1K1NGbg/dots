#!/bin/bash

# Check if NetworkManager is available
if ! command -v nmcli &> /dev/null; then
    echo "nmcli (NetworkManager) is not installed. Please install NetworkManager"
    exit 1
fi

# WiFi status functions
get_wifi_status() {
    local wifi_status=$(nmcli radio wifi)
    local connection_status=$(nmcli -t -f STATE general)
    
    if [[ "$wifi_status" == "enabled" ]]; then
        if [[ "$connection_status" == "connected" ]]; then
            local current_ssid=$(nmcli -t -f GENERAL.CONNECTION dev show | head -1 | cut -d: -f2)
            if [[ -n "$current_ssid" ]]; then
                echo "📶 Connected to: $current_ssid"
            else
                echo "📶 WiFi enabled, not connected"
            fi
        else
            echo "📶 WiFi enabled, disconnected"
        fi
    else
        echo "📵 WiFi disabled"
    fi
}

get_internet_status() {
    if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        echo "🌐 Internet: Connected"
    else
        echo "🌐 Internet: Disconnected"
    fi
}

get_known_networks() {
    echo "⬅️ Back"
    echo "---"
    # Get saved WiFi connections
    nmcli -t -f NAME,TYPE connection show | grep wireless | cut -d: -f1 | while read -r network; do
        echo "📡 $network"
    done
}

get_vpns() {
    echo "⬅️ Back"
    echo "---"
    # Get all VPN connections (both active and inactive)
    # Check if there are any active VPN connections first
    active_vpns=$(nmcli -t -f NAME,TYPE connection show --active | grep -E "(vpn|wireguard)" | cut -d: -f1)
    
    if [[ -n "$active_vpns" ]]; then
        # Show only active VPNs
        echo "$active_vpns" | while read -r vpn; do
            echo "🔒 VPN: $vpn (Connected)"
        done
    else
        # Show all VPNs if none are active
        nmcli -t -f NAME,TYPE connection show | grep -E "(vpn|wireguard)" | cut -d: -f1 | while read -r vpn; do
            echo "🔒 VPN: $vpn (Disconnected)"
        done
    fi
}

# If no arguments, show the menu
if [[ $# -eq 0 ]]; then
    echo "$(get_wifi_status)"
    echo "$(get_internet_status)"
    echo "---"
    
    # WiFi control options
    wifi_status=$(nmcli radio wifi)
    if [[ "$wifi_status" == "enabled" ]]; then
        echo "📵 Turn WiFi Off"
        echo "🔄 Disconnect"
        echo "📡 Known Networks"
        echo "🔒 VPN Menu"
    else
        echo "📶 Turn WiFi On"
    fi
    
    exit 0
fi

# Handle menu selection
case "$1" in
    *"Turn WiFi Off")
        nmcli radio wifi off
        ;;
    *"Turn WiFi On")
        nmcli radio wifi on
        ;;
    *"Disconnect")
        # Disconnect from current WiFi
        current_connection=$(nmcli -t -f NAME,TYPE connection show --active | grep wireless | cut -d: -f1)
        nmcli connection down "$current_connection" &>/dev/null
        ;;
    *"VPN Menu")
        get_vpns
        ;;
    *"Known Networks")
        get_known_networks
        ;;
    *"Back")
        # Go back to main menu
        exec "$0"
        ;;
    📡*)
        # Connect to a known network
        network_name=$(echo "$1" | sed 's/📡 //')
        nmcli connection up "$network_name" &>/dev/null
        ;;
    🔒*)
        # Handle VPN connections
        vpn_line=$(echo "$1" | sed 's/🔒 VPN: //')
        vpn_name=$(echo "$vpn_line" | sed 's/ (Connected)//' | sed 's/ (Disconnected)//')
        
        if [[ "$vpn_line" == *"(Connected)"* ]]; then
            # Disconnect VPN
            nmcli connection down "$vpn_name" &>/dev/null
        else
            # Connect VPN
            nmcli connection up "$vpn_name" &>/dev/null
        fi
        ;;
    *)
        # If it's a status line, just exit
        exit 0
        ;;
esac

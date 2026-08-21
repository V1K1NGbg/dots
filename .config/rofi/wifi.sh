#!/usr/bin/env bash

# Check if NetworkManager is available
if ! command -v nmcli &> /dev/null; then
    echo "nmcli (NetworkManager) is not installed. Please install NetworkManager"
    exit 1
fi

# Rofi initializes every configured script mode when it opens. Keep this mode's
# initial request to one cached device-status query and never trigger a Wi-Fi
# scan just to populate the mode switcher.
show_main_menu() {
    local wifi_row wifi_state connection_name

    wifi_row=$(
        nmcli -t -f TYPE,STATE,CONNECTION device status \
            | awk -F: '$1 == "wifi" || $1 == "802-11-wireless" { print; exit }'
    )

    if [[ -z "$wifi_row" ]]; then
        wifi_state="unavailable"
        connection_name=""
    else
        IFS=: read -r _ wifi_state connection_name <<<"$wifi_row"
    fi

    case "$wifi_state" in
        connected)
            echo "📶 Connected to: $connection_name"
            ;;
        disconnected|connecting)
            echo "📶 WiFi enabled, $wifi_state"
            ;;
        *)
            echo "📵 WiFi disabled"
            ;;
    esac

    echo "---"
    if [[ "$wifi_state" == "unavailable" || "$wifi_state" == "unmanaged" ]]; then
        echo "📶 Turn WiFi On"
    else
        echo "📵 Turn WiFi Off"
        [[ "$wifi_state" == "connected" ]] && echo "🔄 Disconnect"
        echo "📡 Known Networks"
        echo "🔒 VPN Menu"
    fi
}

get_known_networks() {
    echo "⬅️ Back"
    echo "---"
    # Get saved WiFi connections
    nmcli -t -f NAME,TYPE connection show \
        | awk -F: '$2 == "802-11-wireless" || $2 == "wifi" { print $1 }' \
        | while read -r network; do
        echo "📡 $network"
    done
}

get_vpns() {
    local active_vpns
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
    show_main_menu
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
        current_connection=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2 == "802-11-wireless" || $2 == "wifi" {print $1; exit}')
        [[ -n "$current_connection" ]] && nmcli connection down "$current_connection" &>/dev/null
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
        network_name=${1#📡 }
        nmcli connection up "$network_name" &>/dev/null
        ;;
    🔒*)
        # Handle VPN connections
        vpn_line=${1#🔒 VPN: }
        vpn_name=${vpn_line% (Connected)}
        vpn_name=${vpn_name% (Disconnected)}
        
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

#!/usr/bin/env bash

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
    nmcli -t -f NAME,TYPE connection show \
        | awk -F: '$2 == "802-11-wireless" || $2 == "wifi" { print "📡 " $1 }'
}

get_vpns() {
    local active_vpns
    echo "⬅️ Back"
    echo "---"
    active_vpns=$(nmcli -t -f NAME,TYPE connection show --active \
        | awk -F: '/(vpn|wireguard)/ { print $1 }')
    
    if [[ -n "$active_vpns" ]]; then
        while read -r vpn; do
            echo "🔒 VPN: $vpn (Connected)"
        done <<<"$active_vpns"
    else
        nmcli -t -f NAME,TYPE connection show \
            | awk -F: '/(vpn|wireguard)/ { print "🔒 VPN: " $1 " (Disconnected)" }'
    fi
}

if [[ $# -eq 0 ]]; then
    show_main_menu
    exit 0
fi

case "$1" in
    *"Turn WiFi Off")
        nmcli radio wifi off
        ;;
    *"Turn WiFi On")
        nmcli radio wifi on
        ;;
    *"Disconnect")
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
        exec "$0"
        ;;
    📡*)
        network_name=${1#📡 }
        nmcli connection up "$network_name" &>/dev/null
        ;;
    🔒*)
        vpn_line=${1#🔒 VPN: }
        vpn_name=${vpn_line% (Connected)}
        vpn_name=${vpn_name% (Disconnected)}
        
        if [[ "$vpn_line" == *"(Connected)"* ]]; then
            action=down
        else
            action=up
        fi
        nmcli connection "$action" "$vpn_name" &>/dev/null
        ;;
    *)
        exit 0
        ;;
esac

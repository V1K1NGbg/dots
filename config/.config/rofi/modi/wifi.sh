#!/usr/bin/env bash

if ! command -v nmcli &> /dev/null; then
    echo "nmcli (NetworkManager) is not installed. Please install NetworkManager"
    exit 1
fi

# Rofi initializes every configured script mode when it opens. Keep this mode's
# initial request to one cached device-status query and never trigger a Wi-Fi
# scan just to populate the mode switcher.
show_main_menu() {
    local devices wifi_row wifi_state connection_name

    devices=$(nmcli -t -e no -f TYPE,STATE,CONNECTION device status) || return
    wifi_row=$(awk -F: '$1 == "wifi" || $1 == "802-11-wireless" { print; exit }' <<<"$devices")

    if [[ -z "$wifi_row" ]]; then
        wifi_state="unavailable"
        connection_name=""
    else
        wifi_state=${wifi_row#*:}; connection_name=${wifi_state#*:}
        wifi_state=${wifi_state%%:*}
    fi

    case "$wifi_state" in
        connected)
            echo "Connected to: $connection_name"
            ;;
        disconnected|connecting)
            echo "Wi-Fi enabled, $wifi_state"
            ;;
        *)
            echo "Wi-Fi disabled"
            ;;
    esac

    echo "---"
    if [[ "$wifi_state" == "unavailable" || "$wifi_state" == "unmanaged" ]]; then
        echo "Turn Wi-Fi On"
    else
        echo "Turn Wi-Fi Off"
        [[ "$wifi_state" == "connected" ]] && echo "Disconnect"
        echo "Known Networks"
        echo "VPN Menu"
    fi
}

connection_rows() {
    # Names come last so colons/backslashes remain literal data.
    local rows row type uuid name
    rows=$(nmcli -t -e no -f TYPE,UUID,NAME connection show "$@") || return
    [[ -n $rows ]] || return 0
    # ponytail: this menu is line-based; reject control characters rather than
    # presenting a truncated name. Structured rows are needed to support them.
    while IFS= read -r row; do
        type=${row%%:*}; name=${row#*:}
        uuid=${name%%:*}; name=${name#*:}
        if [[ ! $uuid =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ||
              $name == *[[:cntrl:]]* ]]; then
            echo 'Unable to display these connection names safely; remove control characters in NetworkManager.' >&2
            return 1
        fi
    done <<<"$rows"
    printf '%s\n' "$rows"
}

find_connection() {
    local kind=$1 wanted=$2 rows row type uuid name found='' actual
    rows=$(connection_rows) || return
    while IFS= read -r row; do
        type=${row%%:*}; name=${row#*:}
        uuid=${name%%:*}; name=${name#*:}
        case "$kind:$type" in
            wifi:wifi|wifi:802-11-wireless|vpn:vpn|vpn:wireguard) ;;
            *) continue;;
        esac
        [[ $name == "$wanted" ]] || continue
        [[ -z $found ]] || { echo 'Several connections use this name; give them distinct names in NetworkManager.' >&2; return 1; }
        found=$uuid
    done <<<"$rows"
    [[ -n $found ]] || { echo 'The selected connection no longer exists.' >&2; return 1; }
    # Verify the name for this UUID, including trailing newlines. A renamed
    # profile or a name that resembled another table row must not redirect us.
    actual=$(nmcli -e no -g connection.id connection show uuid "$found" && printf '.') || return
    actual=${actual%.}; actual=${actual%$'\n'}
    [[ $actual == "$wanted" ]] || { echo 'The connection name changed or cannot be represented in this menu; refresh the list.' >&2; return 1; }
    printf '%s\n' "$found"
}

get_known_networks() {
    local rows row type name
    rows=$(connection_rows) || return
    echo "Back"
    echo "---"
    while IFS= read -r row; do
        type=${row%%:*}; name=${row#*:*:}
        case $type in wifi|802-11-wireless) printf 'Network: %s\n' "$name";; esac
    done <<<"$rows"
}

get_vpns() {
    local rows row type name status=Connected
    rows=$(connection_rows --active) || return
    if ! awk -F: '$1 == "vpn" || $1 == "wireguard" { found=1 } END { exit !found }' <<<"$rows"; then
        rows=$(connection_rows) || return
        status=Disconnected
    fi
    echo "Back"
    echo "---"
    while IFS= read -r row; do
        type=${row%%:*}; name=${row#*:*:}
        case $type in vpn|wireguard) printf 'VPN: %s (%s)\n' "$name" "$status";; esac
    done <<<"$rows"
}

if [[ $# -eq 0 ]]; then
    show_main_menu
    exit $?
fi

case "$1" in
    "Turn Wi-Fi Off")
        nmcli radio wifi off
        ;;
    "Turn Wi-Fi On")
        nmcli radio wifi on
        ;;
    "Disconnect")
        rows=$(connection_rows --active) || exit
        current_connection=$(awk -F: '$1 == "802-11-wireless" || $1 == "wifi" {print $2; exit}' <<<"$rows")
        [[ -n "$current_connection" ]] && nmcli connection down uuid "$current_connection" >/dev/null
        ;;
    "VPN Menu")
        get_vpns
        ;;
    "Known Networks")
        get_known_networks
        ;;
    "Back")
        exec "$0"
        ;;
    Network:*)
        network_name=${1#Network: }
        uuid=$(find_connection wifi "$network_name") || exit
        nmcli connection up uuid "$uuid" >/dev/null
        ;;
    VPN:*)
        vpn_line=${1#VPN: }
        case $vpn_line in
            *' (Connected)') action=down; vpn_name=${vpn_line% (Connected)};;
            *' (Disconnected)') action=up; vpn_name=${vpn_line% (Disconnected)};;
            *) echo 'Invalid VPN selection.' >&2; exit 1;;
        esac
        uuid=$(find_connection vpn "$vpn_name") || exit
        nmcli connection "$action" uuid "$uuid" >/dev/null
        ;;
    *)
        exit 0
        ;;
esac

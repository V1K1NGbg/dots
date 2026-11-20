#!/usr/bin/env bash
# Sourced by launcher.sh. Wi-Fi, VPN and Bluetooth share one flat page; every
# row carries its action (by UUID or MAC), so names are never parsed back.
network_rows() {
    local devices state='' connection='' connections ssids type uuid active name mac powered=no
    local connected=() wifi=() vpn=() bt=() i
    ROWS=() ACTIONS=() MESSAGE=''
    if command -v nmcli >/dev/null; then
        devices=$(timeout 3 nmcli -t -e no -f TYPE,STATE,CONNECTION device status 2>/dev/null) || devices=
        IFS=: read -r _ state connection < <(grep -m1 -E '^(wifi|802-11-wireless):' <<<"$devices") || :
        ROWS+=('## Wi-Fi'); ACTIONS+=('')
        case $state in
            ''|unavailable|unmanaged) MESSAGE='Wi-Fi off'; ROWS+=('Turn Wi-Fi on'); ACTIONS+=(wifi-on);;
            *)
                if [[ $state == connected ]]; then MESSAGE="Wi-Fi: ${connection//[[:cntrl:]]/ }"; else MESSAGE="Wi-Fi $state"; fi
                ROWS+=('Turn Wi-Fi off'); ACTIONS+=(wifi-off)
                # NAME comes last so colons in names stay literal.
                connections=$(timeout 3 nmcli -t -e no -f TYPE,UUID,ACTIVE,NAME connection show 2>/dev/null) || connections=
                # Known networks are listed only when in range (cached scan, no rescan).
                ssids=$'\n'$(timeout 3 nmcli -t -e no -f SSID device wifi list --rescan no 2>/dev/null)$'\n'
                while IFS=: read -r type uuid active name; do
                    name=${name//[[:cntrl:]]/ }
                    case $type in
                        wifi|802-11-wireless)
                            if [[ $active == yes ]]; then wifi=("● $name · connected" "down:$uuid" "${wifi[@]}")
                            elif [[ $ssids == *$'\n'"$name"$'\n'* ]]; then wifi+=("○ $name" "up:$uuid"); fi;;
                        vpn|wireguard)
                            if [[ $active == yes ]]; then vpn+=("● $name · connected" "down:$uuid")
                            else vpn+=("○ $name" "up:$uuid"); fi;;
                    esac
                done <<<"$connections"
                for ((i=0; i<${#wifi[@]}; i+=2)); do ROWS+=("${wifi[i]}"); ACTIONS+=("${wifi[i+1]}"); done
                ((${#vpn[@]})) && { ROWS+=('## VPN'); ACTIONS+=(''); }
                for ((i=0; i<${#vpn[@]}; i+=2)); do ROWS+=("${vpn[i]}"); ACTIONS+=("${vpn[i+1]}"); done;;
        esac
    fi
    if command -v bluetoothctl >/dev/null; then
        powered=$(timeout 2 bluetoothctl show 2>/dev/null | awk '$1 == "Powered:" {print $2; exit}')
        ROWS+=('## Bluetooth'); ACTIONS+=('')
        if [[ $powered == yes ]]; then
            ROWS+=('Turn Bluetooth off'); ACTIONS+=(bt-off)
            while read -r _ mac _; do [[ -n $mac ]] && connected+=("$mac"); done < <(timeout 2 bluetoothctl devices Connected 2>/dev/null)
            while read -r _ mac name; do
                [[ $mac =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || continue
                name=${name//[[:cntrl:]]/ }
                if [[ " ${connected[*]} " == *" $mac "* ]]; then bt=("● $name · connected" "bt-disconnect:$mac" "${bt[@]}")
                else bt+=("○ $name" "bt-connect:$mac"); fi
            done < <(timeout 2 bluetoothctl devices Paired 2>/dev/null)
            for ((i=0; i<${#bt[@]}; i+=2)); do ROWS+=("${bt[i]}"); ACTIONS+=("${bt[i+1]}"); done
            MESSAGE+="${MESSAGE:+ · }Bluetooth: ${#connected[@]} connected"
        else
            ROWS+=('Turn Bluetooth on'); ACTIONS+=(bt-on)
            MESSAGE+="${MESSAGE:+ · }Bluetooth off"
        fi
    fi
    ((${#ROWS[@]})) || { MESSAGE='Install NetworkManager or bluez-utils.'; return 1; }
}
network_menu() {
    local action error selected=0 stay
    while :; do
        network_rows || { info 'Wi-Fi & Bluetooth' "$MESSAGE" || :; return 10; }
        choose 'Wi-Fi & Bluetooth' "$MESSAGE" list -selected-row "$selected" < <(printf '%s\n' "${ROWS[@]}") || return
        [[ $CHOICE == refresh ]] && continue
        action=${ACTIONS[CHOICE]:-}; selected=$CHOICE; stay=true
        case $action in
            wifi-on) error=$(nmcli radio wifi on 2>&1);;
            wifi-off) error=$(nmcli radio wifi off 2>&1);;
            bt-on) error=$(bluetoothctl power on 2>&1 >/dev/null);;
            bt-off) error=$(bluetoothctl power off 2>&1 >/dev/null);;
            up:*|down:*) stay=false; error=$(nmcli connection "${action%%:*}" uuid "${action#*:}" 2>&1 >/dev/null);;
            bt-connect:*|bt-disconnect:*)
                stay=false; action=${action#bt-}; error=$(timeout 15 bluetoothctl "${action%%:*}" "${action#*:}" 2>&1)
                [[ $error != *'Failed'* ]] || false;;
            *) continue;;
        esac || { info 'Wi-Fi & Bluetooth' "${error:-Network action failed.}" || :; continue; }
        $stay || return 0
        # Toggles stay open so the newly listed networks or devices are reachable.
        [[ $action != *-on ]] || sleep 1
    done
}

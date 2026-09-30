#!/usr/bin/env bash
# Sourced by launcher.sh; uses the shared menu helpers.
network_menu() {
    local title=$1 script=$ROOT/modi/$1.sh current='' rows result value message history=()
    case $title in wifi) title=Wi-Fi;; bluetooth) title=Bluetooth;; esac
    while :; do
        if ! rows=$("$script" ${current:+"$current"} 2>&1); then
            info "$title" "${rows:-Unable to read network status}" || :
            return 10
        fi
        message=''
        if [[ -z $current && $rows == *$'\n---\n'* ]]; then
            message=${rows%%$'\n---\n'*}
            rows=${rows#*$'\n---\n'}
        fi
        rows=$(sed '/^---$/d' <<<"$rows")
        if ! choose "$title" "$message" list <<<"$rows"; then
            return 10
        fi
        [[ $CHOICE == refresh ]] && continue
        value=$(sed -n "$((CHOICE+1))p" <<<"$rows")
        case $value in
            Back)
                ((${#history[@]})) || return 10
                current=${history[${#history[@]}-1]}; unset "history[$((${#history[@]}-1))]";;
            'Known Networks'|'VPN Menu'|'Paired Devices') history+=("$current"); current=$value;;
            *)
                if ! result=$("$script" "$value" 2>&1); then
                    info "$title" "${result:-Network action failed}" || :
                    return 10
                fi
                return 0;;
        esac
    done
}

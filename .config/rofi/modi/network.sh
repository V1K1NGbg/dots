#!/usr/bin/env bash
# Sourced by launcher.sh; uses the shared menu helpers.
network_menu() {
    local title=$1 script=$ROOT/modi/$1.sh current='' rows result value message history=()
    case $title in wifi) title=Wi-Fi;; bluetooth) title=Bluetooth;; esac
    while :; do
        if [[ -n $current ]]; then rows=$("$script" "$current"); else rows=$("$script"); fi
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
        if [[ $value == *Back* ]] && ((${#history[@]})); then current=${history[${#history[@]}-1]}; unset "history[$((${#history[@]}-1))]"; continue; fi
        result=$("$script" "$value")
        if [[ -n $result ]]; then history+=("$current"); current=$value; else return; fi
    done
}

#!/usr/bin/env bash
power_menu() {
    choose Power '' list <<< $'Lock screen\nSuspend\nRestart\nShutdown\nPower mode' || return
    case $CHOICE in
        0) hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")' >/dev/null;;
        1) systemctl suspend;;
        2) systemctl reboot;;
        3) systemctl poweroff;;
        4) rofi_native Escape -modi "power-mode:$ROOT/modi/power-mode.sh" -show power-mode;;
    esac
}

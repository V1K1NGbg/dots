#!/usr/bin/env bash
rofi_suspend() { bash "$ROOT/../hypr/scripts/power.sh" suspend; }
power_menu() {
    local error
    choose Power '' list <<< $'Lock screen\nSuspend\nReboot\nShutdown\nPower mode' || return
    case $CHOICE in
        0) hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")' >/dev/null;;
        1) error=$(rofi_suspend 2>&1) || info Suspend "$error";;
        2) systemctl reboot;;
        3) systemctl poweroff;;
        4) rofi_native Escape -modi "power-mode:$ROOT/modi/power-mode.sh" -show power-mode;;
    esac
}

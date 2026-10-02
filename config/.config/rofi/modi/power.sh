#!/usr/bin/env bash
rofi_suspend() { bash "$ROOT/../hypr/scripts/power.sh" suspend; }
brightness_menu() {
    local status device class current percent maximum value error selected=0
    while :; do
        if ! status=$(brightnessctl --class=backlight --machine-readable info 2>&1); then
            info Brightness "Could not read screen brightness: $status" || :; return 1
        fi
        IFS=, read -r device class current percent maximum <<< "$status"
        choose Brightness "Current brightness: $percent" list -selected-row "$selected" <<< $'Increase +5%\nDecrease −5%\nBack' || return
        case $CHOICE in
            0) value=5%+;;
            1) value=5%-;;
            2) return 0;;
            *) continue;;
        esac
        selected=$CHOICE
        if ! error=$(brightnessctl --class=backlight --device="$device" set "$value" 2>&1); then
            info Brightness "Could not change screen brightness: $error" || :; return 1
        fi
    done
}
power_menu() {
    local error caffeine=Off
    [[ ! -f ${XDG_RUNTIME_DIR:?}/dots-power/caffeine ]] || caffeine=On
    choose Power '' list <<< $'Lock screen\nSuspend\nReboot\nShutdown\nPower mode\nCaffeine: '"$caffeine"$'\nBrightness' || return
    case $CHOICE in
        0) hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")' >/dev/null;;
        1) error=$(rofi_suspend 2>&1) || info Suspend "$error";;
        2) systemctl reboot;;
        3) systemctl poweroff;;
        4) rofi_native Escape -modi "power-mode:$ROOT/modi/power-mode.sh" -show power-mode;;
        5) error=$(bash "$ROOT/../hypr/scripts/power.sh" caffeine 2>&1) || info Caffeine "$error";;
        6) brightness_menu;;
    esac
}

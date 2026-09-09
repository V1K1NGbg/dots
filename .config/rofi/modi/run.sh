#!/usr/bin/env bash
run_menu() {
    local back_keys=Tab ROFI_CANCEL_KEYS=Escape
    if [[ ${1:-direct} == menu ]]; then back_keys=Tab,Escape; ROFI_CANCEL_KEYS=''; fi
    rofi_native "$back_keys" -modi run -show run -display-run Run -show-icons \
        -theme-str 'element { children: [element-icon, element-text]; }' \
        -terminal alacritty -kb-element-next '' -kb-row-tab ''
}

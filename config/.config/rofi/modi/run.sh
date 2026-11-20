#!/usr/bin/env bash
# Run is opened directly (Super+R); Tab returns 10 so the launcher shows the menu.
run_menu() {
    ROFI_CANCEL_KEYS=Escape rofi_native Tab -modi run -show run -display-run Run -show-icons \
        -theme-str 'element { children: [element-icon, element-text]; }' \
        -terminal alacritty -kb-element-next '' -kb-row-tab ''
}

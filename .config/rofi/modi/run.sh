#!/usr/bin/env bash
run_menu() {
    rofi_native 'Tab,Escape' -modi run -show run -display-run Run -show-icons \
        -theme-str 'element { children: [element-icon, element-text]; }' \
        -terminal alacritty -kb-element-next '' -kb-row-tab ''
}

#!/usr/bin/env bash
# Run with bash tests/brightness.sh; no display hardware is touched.
set -euo pipefail
cd "$(dirname "$0")/.."
source config/.config/rofi/modi/power.sh
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
step=0
failure=''
brightnessctl() {
    [[ $1 == --class=backlight ]]
    if [[ $2 == --machine-readable ]]; then
        [[ $failure != read ]] || { echo unavailable >&2; return 1; }
        echo 'intel_backlight,backlight,500,50%,1000'
    else
        [[ $2 == --device=intel_backlight && $3 == set ]]
        [[ $failure != write ]] || { echo denied >&2; return 1; }
        printf '%s\n' "$4" >> "$work/changes"
    fi
}
choose() {
    [[ $2 == 'Current brightness: 50%' ]]
    [[ $4 == -selected-row && $5 == $((step > 0 ? step-1 : 0)) ]]
    CHOICE=$step
    step=$((step+1))
}
info() { printf '%s\n' "$2" > "$work/error"; }
brightness_menu
[[ $(cat "$work/changes") == $'5%+\n5%-' && $step == 3 ]]
failure=read
if brightness_menu; then exit 1; fi
[[ $(cat "$work/error") == *unavailable* ]]
failure=write; step=0
if brightness_menu; then exit 1; fi
[[ $(cat "$work/error") == *denied* ]]
choose() { return 1; }
failure=''
if brightness_menu; then exit 1; fi
[[ $(cat "$work/changes") == $'5%+\n5%-' ]]
echo 'Brightness checks passed.'

#!/usr/bin/env bash
# Run with bash tests/music.sh; no audio commands reach the desktop.
set -euo pipefail
cd "$(dirname "$0")/.."
source config/.config/rofi/modi/music.sh
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
echo 50 > "$work/volume"
step=0
playerctl() { echo 'Test track'; }
wpctl() {
    local volume
    volume=$(cat "$work/volume")
    if [[ $1 == get-volume ]]; then printf 'Volume: 0.%s\n' "$volume"; return; fi
    case ${*: -1} in
        5%+) volume=$((volume+5));;
        5%-) volume=$((volume-5));;
        *) return 1;;
    esac
    echo "$volume" > "$work/volume"
}
choose() {
    case $step in
        0) [[ $5 == 0 && $2 == *'Volume 50%'* ]]; CHOICE=5;;
        1) [[ $5 == 5 && $2 == *'Volume 55%'* ]]; CHOICE=4;;
        2) [[ $5 == 4 && $2 == *'Volume 50%'* ]]; CHOICE=0;;
        *) exit 1;;
    esac
    step=$((step+1))
}
info() { echo "$*" >&2; exit 1; }
music_menu
[[ $step == 3 && $(cat "$work/volume") == 50 ]]
echo 'Music checks passed.'

#!/usr/bin/env bash
# Read-only navigation check inside the laptop's Hyprland session.
set -euo pipefail
repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
layers() { hyprctl layers -j | jq '[.[]|.levels[]|.[]|select(.namespace=="rofi")]|length'; }
key() { hyprctl dispatch "hl.dsp.send_shortcut({mods=\"\",key=\"$1\"})" >/dev/null; }
[[ $(layers) == 0 ]] || { echo 'Close Rofi first.' >&2; exit 1; }
child=''
trap '[[ -z $child ]] || { kill "$child" 2>/dev/null || :; wait "$child" 2>/dev/null || :; }' EXIT
for mode in run music outputs time ai power calc clipboard window autocorrector wifi bluetooth power-mode; do
    bash "$repo/.config/rofi/launcher.sh" "$mode" >/tmp/dots-rofi-navigation.log 2>&1 & child=$!
    for ((i=0;i<100;i++)); do [[ $(layers) != 0 ]] && break; sleep .05; done
    [[ $(layers) != 0 ]]
    sleep .3
    key Escape
    sleep 1
    if [[ $mode == run ]]; then
        ! kill -0 "$child" 2>/dev/null
        [[ $(layers) == 0 ]]
        wait "$child"; child=''
        printf 'PASS: direct Run → Escape → close\n'
        bash "$repo/.config/rofi/launcher.sh" run >/tmp/dots-rofi-navigation.log 2>&1 & child=$!
        for ((i=0;i<100;i++)); do [[ $(layers) != 0 ]] && break; sleep .05; done
        [[ $(layers) != 0 ]]
        sleep .3
        key Tab; sleep 1
    fi
    kill -0 "$child"
    [[ $(layers) != 0 ]]
    # The menu's 'a' shortcut must open Run, which then returns to the menu.
    key a; sleep .4; key Escape; sleep .6
    kill -0 "$child"
    key Escape
    for ((i=0;i<100;i++)); do kill -0 "$child" 2>/dev/null || break; sleep .05; done
    ! kill -0 "$child" 2>/dev/null
    wait "$child"; child=''
    if [[ $mode == run ]]; then
        printf 'PASS: direct Run → Tab → menu → Run → menu → close\n'
    else
        printf 'PASS: %s → Escape → menu → Run → menu → close\n' "$mode"
    fi
done

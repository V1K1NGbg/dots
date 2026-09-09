#!/usr/bin/env bash
# Exercise the installed local-model UI without changing the clipboard.
set -euo pipefail
source "$HOME/.config/rofi/modi/common.sh"
if [[ ${1:-} == --child ]]; then menu_setup; live_menu ai || :; exit; fi
layers() { hyprctl layers -j | jq '[.[]|.levels[]|.[]|select(.namespace=="rofi")]'; }
[[ $(layers | jq length) == 0 ]] || { printf 'Close rofi before this check.\n' >&2; exit 1; }
! systemctl --user is-active --quiet dots-rofi-ai.service
output=$(mktemp -d /tmp/dots-ai-live.XXXXXX); child=''
cleanup() {
    if [[ -n $child ]]; then
        hyprctl dispatch 'hl.dsp.send_shortcut({mods="",key="Escape"})' >/dev/null || :
        kill "$child" 2>/dev/null || :; wait "$child" 2>/dev/null || :
    fi
    "$ROOT/modi/ai.sh" cancel-running >/dev/null 2>&1 || :
}
trap cleanup EXIT
open_ui() {
    bash "$0" --child > "$output/ui.log" 2>&1 & child=$!
    for attempt in {1..100}; do
        [[ $(layers | jq length) == 0 ]] || return 0
        kill -0 "$child" 2>/dev/null || { cat "$output/ui.log"; return 1; }
        sleep .05
    done
    return 1
}
close_ui() {
    hyprctl dispatch "hl.dsp.send_shortcut({mods=\"\",key=\"$1\"})" >/dev/null
    for attempt in {1..100}; do kill -0 "$child" 2>/dev/null || break; sleep .05; done
    ! kill -0 "$child" 2>/dev/null
    wait "$child"; child=''
}
printf 'What is 2 + 2? Reply only with the number.' | "$ROOT/modi/ai.sh" start
open_ui
for attempt in {1..350}; do
    status=$("$ROOT/modi/ai.sh" status | jq -r .status)
    [[ $status == running ]] || break
    sleep .1
done
[[ $status == done ]] || { cat "$RUNTIME/ai.json"; exit 1; }
jq -e '.answer|contains("4")' "$RUNTIME/ai.json" >/dev/null
sleep .4
geometry=$(layers | jq -r '.[0]|"\(.x),\(.y) \(.w)x\(.h)"')
grim -g "$geometry" "$output/answer.png"
close_ui Escape
! systemctl --user is-active --quiet dots-rofi-ai.service
printf 'Explain why leaves change colour in autumn.' | "$ROOT/modi/ai.sh" start
open_ui
[[ $("$ROOT/modi/ai.sh" status | jq -r .status) == running ]]
sleep .1
geometry=$(layers | jq -r '.[0]|"\(.x),\(.y) \(.w)x\(.h)"')
grim -g "$geometry" "$output/cancel.png"
close_ui Return
! systemctl --user is-active --quiet dots-rofi-ai.service
printf 'PASS: automatic AI completion, Escape cleanup and Cancel; screenshots: %s\n' "$output"

#!/usr/bin/env bash
# Run inside Hyprland. Test menus never invoke the selected actions.
set -euo pipefail
repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
source "$repo/.config/rofi/modi/common.sh"
source "$ROOT/modi/files.sh"
source "$ROOT/modi/run.sh"
for module in power music time; do source "$ROOT/modi/$module.sh"; done
if [[ ${1:-} == --child ]]; then
    menu_setup
    case $2 in
        home) choose Menu "$(dashboard)" home < <(home_rows) || CHOICE=cancel;;
        run) rc=0; run_menu || rc=$?; if ((rc==10)); then CHOICE=menu; else CHOICE=closed; fi;;
        timer) live_menu time timer || :; CHOICE=closed;;
        spelling) live_menu autocorrect || :; CHOICE=closed;;
        power|music|time|outputs) "${2}_menu" || :; CHOICE=closed;;
        calc) "${ROFI[@]}" -modi calc -show calc -filter 'sqrt(144)' || :; CHOICE=closed;;
        typing) choose 'Typing test' '' list <<< $'alpha file\nzulu file' || CHOICE=cancel;;
    esac
    printf '%s\n' "$CHOICE"; exit
fi
layers() { hyprctl layers -j | jq '[.[]|.levels[]|.[]|select(.namespace=="rofi")]'; }
[[ $(layers | jq length) == 0 ]] || { printf 'Close the existing rofi menu first.\n' >&2; exit 1; }
focus=$(hyprctl activewindow -j | jq -r '.address//empty')
output=$(mktemp -d "${TMPDIR:-/tmp}/dots-rofi-live.XXXXXX")
child=''
cleanup() {
    if [[ -n $child ]]; then
        hyprctl dispatch 'hl.dsp.send_shortcut({mods="",key="Escape"})' >/dev/null 2>&1 || :
        kill "$child" 2>/dev/null || :; wait "$child" 2>/dev/null || :
    fi
    if [[ $focus =~ ^0x[a-fA-F0-9]+$ ]]; then hyprctl dispatch "hl.dsp.focus({window=\"address:$focus\"})" >/dev/null || :; fi
}
trap cleanup EXIT
probe() {
    local kind=$1 expected=$2 key attempt ready=false
    shift 2
    printf 'Testing %s: %s (expect %s)\n' "$kind" "$*" "$expected"
    bash "$0" --child "$kind" > "$output/result" 2> "$output/error" & child=$!
    for attempt in {1..100}; do
        if [[ $(layers | jq length) != 0 ]]; then ready=true; break; fi
        kill -0 "$child" 2>/dev/null || { cat "$output/error" >&2; return 1; }
        sleep .05
    done
    $ready || { printf 'Rofi did not appear\n' >&2; return 1; }
    sleep .3
    if [[ ! -f $output/$kind.png ]] && command -v grim >/dev/null; then
        geometry=$(layers | jq -r '.[0]|"\(.x),\(.y) \(.w)x\(.h)"')
        grim -g "$geometry" "$output/$kind.png"
    fi
    for key in "$@"; do
        hyprctl dispatch "hl.dsp.send_shortcut({mods=\"\",key=\"$key\"})" >/dev/null
        sleep .07
        if [[ $key != Escape ]] && [[ $kind == timer || $kind == spelling ]]; then
            sleep .2
            geometry=$(layers | jq -r '.[0]|"\(.x),\(.y) \(.w)x\(.h)"')
            grim -g "$geometry" "$output/$kind-input.png"
        fi
    done
    for attempt in {1..100}; do kill -0 "$child" 2>/dev/null || break; sleep .05; done
    if kill -0 "$child" 2>/dev/null; then printf 'Menu did not finish: %s, keys %s; logs: %s\n' "$kind" "$*" "$output" >&2; return 1; fi
    wait "$child"; child=''
    [[ $(cat "$output/result") == "$expected" ]] || { cat "$output/result" >&2; return 1; }
    for attempt in {1..40}; do [[ $(layers | jq length) == 0 ]] && break; sleep .05; done
}
if [[ ${1:-} == --gallery ]]; then
    for panel in home run power music time outputs calc; do
        case $panel in home) probe "$panel" cancel Escape;; run) probe "$panel" closed Escape;; *) probe "$panel" closed Escape;; esac
    done
    probe timer closed 1 m Escape
    probe spelling closed t e h Escape
    printf 'Panel screenshots: %s\n' "$output"
    exit
fi
for i in "${!KEYS[@]}"; do probe home "key:$i" "${KEYS[i]}"; done
probe home key:12 Tab
probe run menu Tab
probe run menu f Tab
probe run closed Escape
probe home cancel Escape
probe home 1 Right Return
probe typing 1 z Return
probe timer closed 1 m Escape
probe spelling closed t e h Escape
printf 'Testing fzf Files window and Escape\n'
files_menu; child=$!
client=''
for attempt in {1..100}; do
    client=$(hyprctl clients -j | jq -c '[.[]|select(.class=="dots-files")][0]//empty')
    [[ -z $client ]] || break
    sleep .05
done
[[ -n $client ]] || { printf 'Files window did not appear\n' >&2; exit 1; }
jq -e '.floating==true' <<<"$client" >/dev/null
sleep .5
for key in r o f i; do hyprctl dispatch "hl.dsp.send_shortcut({mods=\"\",key=\"$key\"})" >/dev/null; done
if command -v grim >/dev/null; then
    geometry=$(jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' <<<"$client")
    grim -g "$geometry" "$output/files.png"
fi
hyprctl dispatch 'hl.dsp.send_shortcut({mods="",key="Escape"})' >/dev/null
for attempt in {1..100}; do kill -0 "$child" 2>/dev/null || break; sleep .05; done
if kill -0 "$child" 2>/dev/null; then printf 'fzf did not close on Escape\n' >&2; exit 1; fi
wait "$child"; child=''
printf 'All 12 menu letters, Tab, Escape, arrows and ordinary typing passed. Screenshots: %s\n' "$output"

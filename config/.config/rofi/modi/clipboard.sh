#!/usr/bin/env bash
# Sourced by launcher.sh. Clipboard tools on top, history below. Digits pick
# rows like every other page; letters still filter the history.
clipboard_autocorrect() {
    local text fixed changes
    text=$(mktemp "$RUNTIME/clipboard-text.XXXXXX") || return 1
    fixed=$(mktemp "$RUNTIME/clipboard-fixed.XXXXXX") || { rm -f -- "$text"; return 1; }
    if ! wl-paste --no-newline --type text > "$text" 2>/dev/null || [[ ! -s $text ]]; then
        rm -f -- "$text" "$fixed"; info Autocorrect 'The clipboard has no text.' || :; return 10
    fi
    if ! changes=$("$ROOT/modi/autocorrect.sh" fix "$fixed" < "$text" 2>&1); then
        rm -f -- "$text" "$fixed"; info Autocorrect "${changes:-aspell failed.}" || :; return 10
    fi
    if [[ -z $changes ]]; then
        rm -f -- "$text" "$fixed"; info Autocorrect 'No spelling mistakes found.' || :; return 10
    fi
    # Show the corrections (not the whole text), capped so the page stays small.
    changes=$(head -n 12 <<<"$changes"; (( $(wc -l <<<"$changes") <= 12 )) || printf '…')
    if choose Autocorrect "$changes" list <<<$'Copy corrected text\nBack' && [[ $CHOICE == 0 ]]; then
        wl-copy < "$fixed" 9>&-; rm -f -- "$text" "$fixed"; return 0
    fi
    rm -f -- "$text" "$fixed"; return 10
}
clipboard_menu() {
    local history=() line rc
    command -v cliphist >/dev/null && command -v wl-copy >/dev/null || {
        info 'Clipboard & Spelling' 'cliphist and wl-clipboard are required.' || :; return 10; }
    while :; do
        history=()
        while IFS= read -r line; do history+=("$line"); done < <(cliphist list 2>/dev/null)
        choose 'Clipboard & Spelling' '' list < <(
            printf '%s\n' 'Autocorrect clipboard' 'Spell-check a word' '## History'
            for line in "${history[@]}"; do line=${line#*$'\t'}; line=${line//[[:cntrl:]]/ }; printf '%s\n' "${line:0:200}"; done) || return
        case $CHOICE in
            refresh|2) continue;;
            0) clipboard_autocorrect; rc=$?;;
            1) live_menu autocorrect; rc=$?;;
            *)
                line=${history[CHOICE-3]:-}
                [[ -n $line ]] || continue
                # Decode fully before touching the clipboard; keeps binary bytes.
                local temp
                temp=$(mktemp "$RUNTIME/clipboard.XXXXXX") || return 1
                if cliphist decode <<<"$line" > "$temp"; then wl-copy < "$temp" 9>&-; rc=0; else rc=10; fi
                rm -f -- "$temp";;
        esac
        ((rc==10)) || return "$rc"
    done
}

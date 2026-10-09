#!/usr/bin/env bash
# Sourced by launcher.sh; uses the shared menu helpers.
ai_menu() (
    local mode=new label='' question error path rc action
    local attachment selection
    attachment=$(mktemp "$RUNTIME/ai-attachment.XXXXXX") || return
    selection=$(mktemp "$RUNTIME/ai-selection.XXXXXX") || { rm -f -- "$attachment"; return 1; }
    trap '
        "$ROOT/modi/ai.sh" cancel-running >/dev/null 2>&1 || :
        rm -f -- "$attachment" "$attachment.next" "$selection" "$RUNTIME/ai-action"
    ' EXIT
    while :; do
        if [[ $mode == new ]]; then
            choose 'Ask AI' "${label:+Attached: $label · }Short local answers" list <<< $'Ask a question\nExplain clipboard\nSummarize clipboard\nTranslate clipboard\nRewrite clipboard\nAdd file\nRemove attachment' || return 1
            case $CHOICE in
                0)
                    prompt 'Ask AI' "${label:+Attached: $label · }What would you like to know?" || continue
                    question=$ANSWER;;
                1|2|3|4)
                    action=$CHOICE
                    if ! wl-paste --no-newline --type text 2> "$selection" | bash "$ROOT/modi/ai-request.sh" attachment - > "$attachment.next" 2>> "$selection"; then
                        info 'Clipboard' "$(cat "$selection")" || :; continue
                    fi
                    choose 'Use clipboard' "$(jq -r '.[0:1200]' "$attachment.next")" list <<< $'Use this text\nBack' || continue
                    [[ $CHOICE == 0 ]] || continue
                    case $action in
                        1) question='Explain this text.';;
                        2) question='Summarize this text.';;
                        3) prompt 'Translate clipboard' 'Translate into which language?' || continue
                           [[ -n $ANSWER ]] || continue
                           question="Translate this text into $ANSWER.";;
                        4) prompt 'Rewrite clipboard' 'How should it read? e.g. clearer, shorter, more formal' || continue
                           [[ -n $ANSWER ]] || continue
                           question="Rewrite this text: $ANSWER.";;
                    esac
                    mv -f -- "$attachment.next" "$attachment"
                    label=Clipboard;;
                5)
                    : > "$selection"
                    files_menu "$selection" || continue
                    IFS= read -r -d '' path < "$selection" || continue
                    if ! bash "$ROOT/modi/ai-request.sh" attachment "$path" > "$attachment.next" 2> "$selection"; then
                        info 'Add file' "$(cat "$selection")" || :; continue
                    fi
                    mv -f -- "$attachment.next" "$attachment"
                    label=${path##*/}
                    continue;;
                6) : > "$attachment"; label=''; continue;;
                *) continue;;
            esac
        elif [[ $mode == followup ]]; then
            if ! prompt 'Follow-up' 'Ask about the previous answer or attachment'; then mode=view; continue; fi
            question=$ANSWER
        fi
        if [[ $mode != view ]]; then
            [[ -n $question ]] || continue
            if ! error=$(printf '%s' "$question" | "$ROOT/modi/ai.sh" start "$mode" "$attachment" "$label" 2>&1); then
                info 'Ask AI' "$error" || :; continue
            fi
        fi
        rm -f -- "$RUNTIME/ai-action"
        rc=0; live_menu ai || rc=$?
        action=''; [[ ! -f $RUNTIME/ai-action ]] || read -r action < "$RUNTIME/ai-action"
        case $action in
            followup) mode=followup;;
            new) mode=new; label=''; : > "$attachment";;
            *) return "$rc";;
        esac
    done
)
ai_live() {
    local event name value last='' job status message
    trap '"$ROOT/modi/ai.sh" cancel-running >/dev/null 2>&1 || :' EXIT
    trap 'exit 0' TERM INT HUP
    while :; do
        job=$("$ROOT/modi/ai.sh" status)
        status=$(jq -r '.status//"error"' <<<"$job")
        if [[ $job != "$last" ]]; then
            case $status in
                running)
                    message=$(jq -r '.answer//""' <<<"$job")
                    live_page 'Ask AI' "${message:-Working locally…}" '["Cancel"]';;
                done) live_page 'Ask AI' "$(jq -r .answer <<<"$job")" '["Copy answer","Follow-up","New question","Close"]';;
                *) live_page 'Ask AI' "$(jq -r '.error//"Request failed"' <<<"$job")" '["New question","Close"]';;
            esac
            last=$job
        fi
        if IFS= read -r -t .15 event; then
            name=$(jq -r .name <<<"$event")
            value=$(jq -r '.value//""' <<<"$event")
            case $name in
                'select entry')
                    case $value in
                        'Copy answer') [[ $status != done ]] || jq -jr .answer <<<"$job" | wl-copy;;
                        'Follow-up') [[ $status == done ]] || continue
                            printf 'followup\n' > "$RUNTIME/ai-action"; return;;
                        'New question') printf 'new\n' > "$RUNTIME/ai-action"; return;;
                        Cancel|Close) return;;
                    esac;;
            esac
        else
            # Bash returns 1 for EOF and >128 for the short timeout.
            (( $? > 128 )) || return
        fi
    done
}

# Sourcing defines the menu; direct execution handles the background request.
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then return 0; fi
# systemd owns and cancels the streaming request. No PID files or RPC.
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
if [[ ${1:-status} == live ]]; then ai_live; exit; fi
if [[ ${1:-status} != run ]]; then exec 9>"$RUNTIME/ai.lock"; flock 9; fi
case ${1:-status} in
    status)
        if [[ -f $RUNTIME/ai.json ]] && jq -e '.status=="running"' "$RUNTIME/ai.json" >/dev/null && ! systemctl --user is-active --quiet dots-rofi-ai.service; then
            printf '{"status":"error","error":"Request stopped or timed out"}\n' | atomic "$RUNTIME/ai.json"
        fi
        jq '{status, answer, error}' "$RUNTIME/ai.json" 2>/dev/null || printf '{}';;
    cancel-running)
        if systemctl --user is-active --quiet dots-rofi-ai.service; then systemctl --user stop dots-rofi-ai.service; fi;;
    cancel)
        systemctl --user stop dots-rofi-ai.service || :
        printf '{"status":"error","error":"Cancelled"}\n' | atomic "$RUNTIME/ai.json";;
    start)
        if systemctl --user is-active --quiet dots-rofi-ai.service; then printf 'Cancel the current request first\n' >&2; exit 1; fi
        deadline=$(cfg .ai_timeout); [[ $deadline =~ ^[0-9]+$ ]] && ((deadline>0 && deadline<=3600)) || { printf 'ai_timeout must be 1–3600 seconds\n' >&2; exit 1; }
        bash "$ROOT/modi/ai-request.sh" prepare "$RUNTIME/ai.json" "${2:-new}" "${3:-}" "${4:-}"
        systemd-run --user --collect --quiet --unit=dots-rofi-ai --property="RuntimeMaxSec=$((deadline+5))" "$0" run 9>&- || { printf '{"status":"error","error":"Could not start request"}\n' | atomic "$RUNTIME/ai.json"; exit 1; };;
    run)
        printf '%s' "$CONFIG" | bash "$ROOT/modi/ai-request.sh" run "$RUNTIME/ai.json";;
    *) exit 2;;
esac

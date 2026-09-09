#!/usr/bin/env bash
# Sourced by launcher.sh; uses the shared menu helpers.
ai_menu() (
    prompt 'Ask AI' 'One question · short local answer' || return
    [[ -n $ANSWER ]] || return
    error=$(printf '%s' "$ANSWER" | "$ROOT/modi/ai.sh" start 2>&1) || { info 'Ask AI' "$error"; return; }
    trap '"$ROOT/modi/ai.sh" cancel-running >/dev/null 2>&1 || :' EXIT
    live_menu ai
)
ai_live() {
    local event name last='' job status
    trap '"$ROOT/modi/ai.sh" cancel-running >/dev/null 2>&1 || :' EXIT
    trap 'exit 0' TERM INT HUP
    while :; do
        job=$("$ROOT/modi/ai.sh" status)
        status=$(jq -r '.status//"error"' <<<"$job")
        if [[ $job != "$last" ]]; then
            case $status in
                running) live_page 'Ask AI' 'Working locally…' '["Cancel"]';;
                done) live_page 'Ask AI' "$(jq -r .answer <<<"$job")" '["Copy answer"]';;
                *) live_page 'Ask AI' "$(jq -r '.error//"Request failed"' <<<"$job")" '["Close"]';;
            esac
            last=$job
        fi
        if IFS= read -r -t .15 event; then
            name=$(jq -r .name <<<"$event")
            case $name in
                'select entry'|'execute custom input')
                    if [[ $status == done ]]; then jq -jr .answer <<<"$job" | wl-copy; fi
                    return;;
            esac
        else
            # Bash returns 1 for EOF and >128 for the short timeout.
            (( $? > 128 )) || return
        fi
    done
}

# Sourcing defines the menu; direct execution handles the background request.
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then return 0; fi
# systemd owns the request process and cancels curl with it. No PID files or RPC.
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
if [[ ${1:-status} == live ]]; then ai_live; exit; fi
if [[ ${1:-status} != run ]]; then exec 9>"$RUNTIME/ai.lock"; flock 9; fi
case ${1:-status} in
    status)
        if [[ -f $RUNTIME/ai.json ]] && jq -e '.status=="running"' "$RUNTIME/ai.json" >/dev/null && ! systemctl --user is-active --quiet dots-rofi-ai.service; then
            printf '{"status":"error","error":"Request stopped or timed out"}\n' | atomic "$RUNTIME/ai.json"
        fi
        cat "$RUNTIME/ai.json" 2>/dev/null || printf '{}';;
    cancel-running)
        if systemctl --user is-active --quiet dots-rofi-ai.service; then systemctl --user stop dots-rofi-ai.service; fi;;
    cancel)
        systemctl --user stop dots-rofi-ai.service || :
        printf '{"status":"error","error":"Cancelled"}\n' | atomic "$RUNTIME/ai.json";;
    start)
        if systemctl --user is-active --quiet dots-rofi-ai.service; then printf 'Cancel the current request first\n' >&2; exit 1; fi
        deadline=$(cfg .ai_timeout); [[ $deadline =~ ^[0-9]+$ ]] && ((deadline>0 && deadline<=3600)) || { printf 'ai_timeout must be 1–3600 seconds\n' >&2; exit 1; }
        question=$(cat); [[ -n $question && ${#question} -le 8000 ]] || { printf 'Enter 1–8000 characters\n' >&2; exit 1; }
        jq -n --arg question "$question" '{status:"running",question:$question}' | atomic "$RUNTIME/ai.json"
        systemd-run --user --collect --quiet --unit=dots-rofi-ai --property="RuntimeMaxSec=$((deadline+5))" "$0" run 9>&- || { printf '{"status":"error","error":"Could not start request"}\n' | atomic "$RUNTIME/ai.json"; exit 1; };;
    run)
        start=$(date +%s)
        trap 'rm -f -- "$RUNTIME/ai-response.json" "$RUNTIME/ai-error"' EXIT
        request=$(jq --arg model "$(cfg .ai_model)" '{model:$model,messages:[{role:"system",content:"Answer directly in one to three short sentences. No preamble. No reasoning. If unsure, say so."},{role:"user",content:.question}],max_tokens:128,temperature:0.2,stream:false,cache_prompt:true,chat_template_kwargs:{enable_thinking:false},reasoning_budget:0}' "$RUNTIME/ai.json")
        if curl -fsS --connect-timeout 3 --max-time "$(cfg .ai_timeout)" -H 'Content-Type: application/json' --data-binary "$request" "$(cfg .ai_url)" > "$RUNTIME/ai-response.json" 2> "$RUNTIME/ai-error"; then
            if result=$(jq -e --argjson seconds "$(( $(date +%s)-start ))" '
              .choices[0].message |
              if ((.reasoning_content//"")|length)>0 or ((.content//"")|contains("<think>")) then error("Model generated reasoning despite the no-thinking request")
              elif ((.content//"")|length)==0 then error("Model returned no answer")
              else {status:"done",answer:.content,seconds:$seconds} end' "$RUNTIME/ai-response.json" 2> "$RUNTIME/ai-error"); then
                printf '%s\n' "$result" | atomic "$RUNTIME/ai.json"; exit 0
            fi
        fi
        jq -n --arg error "$(cat "$RUNTIME/ai-error")" '{status:"error",error:($error+" · The local model may be unavailable or busy.")}' | atomic "$RUNTIME/ai.json";;
    *) exit 2;;
esac

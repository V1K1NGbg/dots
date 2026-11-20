#!/usr/bin/env bash
# Sourced by launcher.sh. A live qalc calculator: Enter on the top row copies
# the bare result and closes; every copy is saved to the history listed below.
# Selecting a history row appends its result to the input, so "1+" plus
# "1+1 = 2" becomes "1+2". Rofi-blocks cannot edit the input in place, so the
# live script writes the new input to $RUNTIME/calc-input and exits, and
# calc_menu reopens Rofi with that text prefilled.
CALC_HISTORY=${STATE:-}/calc-history
calc_menu() {
    local input='' command rc height=580
    ((height<=HEIGHT)) || height=$HEIGHT
    while :; do
        rm -f -- "$RUNTIME/calc-input"
        printf -v command '%q ' "$ROOT/modi/calc.sh" live "$input"
        rc=0
        rofi_native Escape -modi blocks -show blocks -blocks-wrap "$command" -filter "$input" \
            -theme-str "window { height: ${height}px; }" || rc=$?
        [[ -f $RUNTIME/calc-input ]] || return "$rc"
        IFS= read -rd '' input < "$RUNTIME/calc-input" || :
    done
}
calc_eval() {
    RESULT=''
    [[ -n ${1//[[:space:]]/} ]] || return 1
    RESULT=$(timeout 2 qalc -t -- "$1" 2>/dev/null | tail -n 1) || RESULT=''
    RESULT=${RESULT//[[:cntrl:]]/ }
    [[ -n $RESULT && $RESULT != *error* ]]
}
calc_page() {
    local message lines
    if calc_eval "$1"; then message="= $RESULT"
    elif [[ -n ${1//[[:space:]]/} ]]; then message='No result'
    else message='Type an expression; pick a past result to append it.'; fi
    # Newest first; the result travels in data so names are never parsed back.
    lines=$(jq -Rnc --arg result "$RESULT" '
        [{text:(if $result=="" then "Copy to clipboard" else "Copy to clipboard: \($result)" end),data:"copy"}] +
        ([inputs|select(test("\t"))|split("\t")|{text:"\(.[0]) = \(.[1])",data:"use:\(.[1])"}]|reverse)' \
        < <([[ -r $CALC_HISTORY ]] && cat -- "$CALC_HISTORY"))
    jq -cn --arg message "$message" --argjson lines "$lines" \
        '{prompt:"Calculator",message:($message|@html),lines:$lines,"active entry":0,"input action":"send","close on exit":true}'
}
calc_live() {
    local input=$1 event name data
    calc_page "$input"
    while IFS= read -r event; do
        name=$(jq -r .name <<<"$event")
        case $name in
            'input change') input=$(jq -r .value <<<"$event"); calc_page "$input";;
            'select entry'|'execute custom input')
                data=$(jq -r .data <<<"$event")
                case $data in
                    use:*) printf '%s%s' "$input" "${data#use:}" > "$RUNTIME/calc-input"; exit;;
                    *)
                        calc_eval "$input" || { calc_page "$input"; continue; }
                        printf '%s' "$RESULT" | wl-copy 9>&-
                        { [[ -r $CALC_HISTORY ]] && tail -n 99 -- "$CALC_HISTORY"
                          printf '%s\t%s\n' "${input//[[:cntrl:]]/ }" "$RESULT"; } | atomic "$CALC_HISTORY"
                        exit;;
                esac;;
        esac
    done
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    source "$(dirname -- "$0")/common.sh"
    CALC_HISTORY=$STATE/calc-history
    [[ ${1:-} == live ]] && calc_live "${2:-}"
fi

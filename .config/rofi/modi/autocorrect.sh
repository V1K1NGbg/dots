#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
live_page Autocorrect 'Type a word; select a suggestion to copy it.' '[]'
while IFS= read -r event; do
    name=$(jq -r .name <<<"$event")
    value=$(jq -r .value <<<"$event")
    case $name in
        'input change')
            if [[ -z $value ]]; then live_page Autocorrect 'Type a word.' '[]'; continue; fi
            # Prefix ^ prevents aspell pipe commands in user input.
            result=$(printf '^%s\n' "${value//$'\n'/ }" | aspell -a)
            suggestions=$(sed -n 's/^&[^:]*: //p' <<<"$result" | tr ',' '\n' | sed 's/^ *//' | jq -Rsc 'split("\n")|map(select(length>0))|reduce .[] as $word ([]; if index($word)==null then .+[$word] else . end)')
            if [[ $suggestions == '[]' ]]; then
                if [[ $result == *$'\n#'* ]]; then live_page Autocorrect 'No suggestions found.' '[]'
                else live_page Autocorrect 'Spelling is correct.' "$(jq -cn --arg word "$value" '[$word]')"; fi
            else live_page Autocorrect 'Select a correction to copy it.' "$suggestions"; fi;;
        'select entry') printf '%s' "$value" | wl-copy; exit;;
    esac
done

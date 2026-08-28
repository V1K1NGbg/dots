#!/usr/bin/env bash

if ! command -v qalc &>/dev/null; then
    echo "qalc is not installed. Please install qalculate-gtk or libqalculate"
    exit 1
fi



calculate() {
    local expression result
    expression=$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<<"$1")

    [[ -n "$expression" ]] || return

    if [[ "$expression" == *"="* ]]; then
        echo "${expression##*= }"
        return
    fi

    if result=$(qalc -t -c -f - 2>/dev/null <<<"$expression") && [[ -n "$result" ]]; then
        result=$(
            sed \
                -e 's/\x1b\[[0-9;]*m//g' \
                -e 's/[[:cntrl:]]//g' \
                -e '/^>.*$/d' \
                -e '/^$/d' \
                <<<"$result" \
                | tail -n 1
        )
        result=$(sed \
            -e 's/^[[:space:]]*//;s/[[:space:]]*$//' \
            -e 's/\.0*$//;s/\.\([0-9]*[1-9]\)0*$/.\1/' \
            <<<"$result")
        echo "$result"
    else
        echo "Error: Invalid expression"
    fi
}
if [[ $# -gt 0 ]]; then
    expression=$1
    result=$(calculate "$expression")
    echo "$expression = $result"
fi

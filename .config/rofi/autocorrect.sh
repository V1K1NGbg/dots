#!/usr/bin/env bash

if ! command -v aspell &>/dev/null; then
    echo "aspell is not installed"
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "✍️ Type Word:"
    exit 0
fi

case "$1" in
    "✍️ Type Word:")
        echo "Type word and press Enter..."
        ;;
    "Type word and press Enter...")
        exit 0
        ;;
    "🟢"*)
        sed -e "s/🟢 '//" -e "s/' is correct//" <<<"$1" | wl-copy
        exit 0
        ;;
    "🔴"*)
        exit 0
        ;;
    "✅"*)
        exit 0
        ;;
    "---")
        exit 0
        ;;
    "-"*)
        printf '%s' "$1" | sed 's/^- //' | wl-copy
        exit 0
        ;;
    *)
        if aspell list <<<"$1" | grep -q .; then
            echo "🔴 '$1' is misspelled"
            echo "---"
            aspell pipe <<<"$1" \
                | grep -Ev '^[@*]|^$' \
                | sed 's/^& .* [0-9]*: //' \
                | tr ',' '\n' \
                | sed 's/^ //' \
                | while read -r suggestion; do
                [[ -n "$suggestion" ]] && echo "- $suggestion"
            done
        else
            echo "🟢 '$1' is correct"
        fi
        exit 0
        ;;
esac

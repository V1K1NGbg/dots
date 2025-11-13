#!/bin/bash

# Check if aspell is available
if ! command -v aspell &> /dev/null; then
    echo "aspell is not installed"
    exit 1
fi

# If no arguments, show the menu
if [[ $# -eq 0 ]]; then
    echo "✍️ Type Word:"
    exit 0
fi

# Handle menu selection
case "$1" in
    "✍️ Type Word:")
        echo "Type word and press Enter..."
        ;;
    "Type word and press Enter...")
        exit 0
        ;;
    "🟢"*)
        echo -n "$1" | sed "s/🟢 '//" | sed "s/' is correct//" | xsel -b >/dev/null 2>&1
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
        echo -n "$1" | sed 's/^- //' | xsel -b >/dev/null 2>&1
        exit 0
        ;;
    *)
        # Check typed word
        if echo "$1" | aspell list | grep -q .; then
            echo "🔴 '$1' is misspelled"
            echo "---"
            echo "$1" | aspell pipe | grep -v "^[@*]" | grep -v "^$" | sed 's/^& .* [0-9]*: //' | tr ',' '\n' | sed 's/^ //' | while read -r suggestion; do
                [[ -n "$suggestion" ]] && echo "- $suggestion"
            done
        else
            echo "🟢 '$1' is correct"
        fi
        exit 0
        ;;
esac

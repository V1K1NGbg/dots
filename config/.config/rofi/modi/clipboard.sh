#!/usr/bin/env bash

set -euo pipefail

if ! command -v cliphist &>/dev/null || ! command -v wl-copy &>/dev/null; then
    echo "cliphist and wl-clipboard are required"
    exit 1
fi

if [[ $# -eq 0 ]]; then
    cliphist list
    exit 0
fi

# Finish decoding before touching the clipboard; keep binary bytes/newlines.
umask 077
temp=$(mktemp "${TMPDIR:-/tmp}/dots-clipboard.XXXXXX")
trap 'rm -f -- "$temp"' EXIT
cliphist decode <<<"$1" > "$temp"
wl-copy < "$temp"

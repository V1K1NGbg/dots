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

cliphist decode <<<"$1" | wl-copy

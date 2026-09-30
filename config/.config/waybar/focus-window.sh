#!/usr/bin/env bash
set -euo pipefail

address=${1:?window address required}
button=${2:-1}
[[ $button == 1 ]] || exit 0
[[ $address =~ ^0x[[:xdigit:]]+$ ]] || exit 1
hyprctl dispatch "function() dots.focus_window('$address') end"

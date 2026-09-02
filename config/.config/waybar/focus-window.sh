#!/usr/bin/env bash
set -euo pipefail

address=${1:?window address required}
hyprctl dispatch focuswindow "address:$address"

#!/usr/bin/env bash

set -euo pipefail

if pgrep -x cava >/dev/null; then
    pkill -x cava
else
    alacritty --class Cava,Cava --title Cava -e cava >/dev/null 2>&1 &
fi

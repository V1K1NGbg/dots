#!/usr/bin/env bash

set -euo pipefail

# Cava is supervised so it remains part of the desktop background. This key
# refreshes it without leaving the wallpaper visualizer stopped.
systemctl --user restart cava-wallpaper.service

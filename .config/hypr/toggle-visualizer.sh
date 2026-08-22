#!/usr/bin/env bash

set -euo pipefail

visualizer_service="kwybars-daemon.service"

if systemctl --user is-active --quiet "$visualizer_service"; then
    systemctl --user stop "$visualizer_service"
else
    systemctl --user start "$visualizer_service"
fi

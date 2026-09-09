#!/usr/bin/env bash
# Compatibility entry point; implementation lives with the rofi assets.
exec bash "$(dirname -- "$0")/../.config/rofi/icon-gen/generate.sh" "$@"

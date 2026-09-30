#!/usr/bin/env bash
set -eu
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
geometry=$(slurp) || exit 0
[[ -n $geometry ]] || exit 0
capture=$(mktemp "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/dots-screenshot.XXXXXXXX")
trap 'rm -f -- "$capture"' EXIT
grim -g "$geometry" "$capture"
# Capture succeeded. Playback failure must not prevent opening the editor.
bash "$root/sound.sh" screenshot >/dev/null 2>&1 &
swappy -f "$capture"

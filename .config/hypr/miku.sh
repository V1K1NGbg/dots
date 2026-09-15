#!/usr/bin/env bash
set -euo pipefail

fail() {
    printf 'Miku: %s\n' "$1" >&2
    notify-send 'Miku' "$1" || :
    exit 1
}

unit=dots-miku.service
data=${XDG_DATA_HOME:-$HOME/.local/share}/dots-miku
directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ ${1:-} == --run ]]; then
    [[ -x $data/bin/shimeji-overlayd ]] || fail 'Run bash scripts/build-miku-renderer.sh from dots first.'
    export PATH="$data/bin:$PATH"
    command -v shimeji-overlayd >/dev/null || fail 'Install wl_shimeji-git first.'
    [[ -f $data/prototypes/Miku/manifest.json ]] || fail 'Run python3 scripts/setup-miku.py from dots first.'
    exec python3 "$directory/miku-input.py"
fi
[[ $# == 0 ]] || fail 'Usage: miku.sh [--run]'
exec 9>"${XDG_RUNTIME_DIR:?}/dots-miku-toggle.lock"
flock 9
if systemctl --user is-active --quiet "$unit"; then
    systemctl --user stop "$unit" || fail 'Could not stop Miku; check journalctl --user -u dots-miku.'
else
    command -v shimeji-overlayd >/dev/null || fail 'Install wl_shimeji-git first.'
    [[ -f $data/prototypes/Miku/manifest.json ]] || fail 'Run python3 scripts/setup-miku.py from dots first.'
    systemctl --user start "$unit" || fail 'Could not start Miku; check journalctl --user -u dots-miku.'
fi

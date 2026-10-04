#!/usr/bin/env bash
set -euo pipefail
directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

build() {
    # Command substitution otherwise clears errexit in Bash.
    set -e
    local cache=${XDG_CACHE_HOME:-$HOME/.cache}/dots-garden temporary
    mkdir -p "$cache"
    exec 8>"$cache/build.lock"
    flock 8
    if [[ ! -x $cache/renderer || $directory/renderer.c -nt $cache/renderer ]]; then
        temporary=$(mktemp "$cache/renderer.XXXXXXXX")
        trap 'rm -f -- "$temporary"' EXIT
        local -a flags
        read -r -a flags <<< "$(pkg-config --cflags --libs gtk+-3.0 gtk-layer-shell-0)"
        clang -O2 -Wall -Wextra -Werror "$directory/renderer.c" -o "$temporary" "${flags[@]}" -lm
        chmod 0755 "$temporary"
        mv -f "$temporary" "$cache/renderer"
        trap - EXIT
    fi
    printf '%s\n' "$cache/renderer"
}

case "${1:-}" in
    --toggle)
        umask 077
        state=${XDG_STATE_HOME:-$HOME/.local/state}/dots-garden
        mkdir -p "$state"
        exec 9>"$state/toggle.lock"
        flock 9
        marker=$state/frozen
        if [[ -e $marker ]]; then
            rm -- "$marker"
            was_frozen=true
        else
            : > "$marker"
            was_frozen=false
        fi
        if ! systemctl --user start dots-garden.service; then
            if $was_frozen; then : > "$marker"; else rm -f -- "$marker"; fi
            exit 1
        fi ;;
    --build) build ;;
    --run|--preview)
        binary=$(build)
        exec "$binary" "$@" ;;
    *) printf 'Usage: %s --toggle | --build | --run | --preview HOURS [PNG]\n' "$0" >&2; exit 2 ;;
esac

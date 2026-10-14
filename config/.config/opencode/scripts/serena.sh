#!/usr/bin/env bash
set -euo pipefail
umask 077

config_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v serena >/dev/null || {
    echo 'Serena is missing. Install it with: paru -S --needed serena; native OpenCode tools remain available.' >&2
    exit 1
}
[[ $# == 0 ]] || { echo 'Usage: serena.sh' >&2; exit 2; }

export SERENA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/serena"
export SERENA_USAGE_REPORTING=false
[[ ! -L $SERENA_HOME && ! -L $SERENA_HOME/serena_config.yml ]] || {
    echo 'Refusing symlinked Serena state.' >&2; exit 1
}
mkdir -p "$SERENA_HOME"
if [[ ! -e $SERENA_HOME/serena_config.yml ]]; then
    # Publish a complete seed atomically; concurrent starts cannot replace state.
    seed=$(mktemp "$SERENA_HOME/.seed.XXXXXXXX")
    trap 'rm -f -- "$seed"' EXIT
    cat "$config_dir/serena/config.yml" > "$seed"
    ln "$seed" "$SERENA_HOME/serena_config.yml" 2>/dev/null ||
        [[ -f $SERENA_HOME/serena_config.yml ]]
    rm -f -- "$seed"
    trap - EXIT
fi
exec serena start-mcp-server \
    --context "$config_dir/serena/context.yml" --project-from-cwd \
    --enable-web-dashboard false --open-web-dashboard false --enable-gui-log-window false

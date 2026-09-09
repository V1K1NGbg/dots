#!/usr/bin/env bash
# fd streams paths directly into fzf; no custom index or presentation cache.
files_menu() {
    alacritty --class dots-files --title 'Files · fzf' \
        -o 'window.dimensions.columns=100' -o 'window.dimensions.lines=28' \
        -o 'window.opacity=1.0' -o 'colors.primary.background="#191919"' \
        -o 'window.padding.x=16' -o 'window.padding.y=16' \
        -e "$ROOT/modi/files.sh" pick 9>&- >/dev/null 2>&1 &
}
files_pick() (
    cd -- "$HOME" || exit
    args=(fd --hidden --no-ignore --type f --type d --type l --print0)
    while IFS= read -r pattern; do args+=(--exclude "$pattern"); done < <(cfg '.exclude[]')
    selected=$(mktemp "$RUNTIME/files-selected.XXXXXX"); trap 'rm -f -- "$selected"' EXIT
    # NUL delimiters preserve filenames containing newlines. No path is evaluated.
    if FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= FZF_DEFAULT_COMMAND= fzf \
        --read0 --print0 --scheme=path --layout=reverse --border=rounded \
        --prompt='Files › ' --header='Home · Enter opens in VS Code · Esc closes' \
        --color='bg:#191919,fg:#f8f8f2,bg+:#303030,fg+:#67ffeb,hl:#67ffeb,hl+:#67ffeb,prompt:#67ffeb,border:#67ffeb' \
        --bind='enter:accept,esc:abort,ctrl-c:abort' < <("${args[@]}" .) > "$selected"; then
        IFS= read -r -d '' path < "$selected" || exit 1
        [[ $path == /* ]] || path=$HOME/$path
        [[ -e $path ]] && code -- "$path"
    fi
)
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    source "$(dirname -- "$0")/common.sh"
    case ${1:-pick} in pick) files_pick;; *) exit 2;; esac
fi

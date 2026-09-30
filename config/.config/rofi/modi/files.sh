#!/usr/bin/env bash
# fd streams paths directly into fzf; no custom index or presentation cache.
files_menu() (
    local result status=0
    result=$(mktemp "$RUNTIME/files-result.XXXXXX") || return 2
    trap '[[ -z ${result:-} ]] || rm -f -- "$result"' EXIT
    if alacritty --class dots-files --title 'Files · fzf' \
        -o 'window.dimensions.columns=100' -o 'window.dimensions.lines=28' \
        -o 'window.opacity=1.0' -o 'colors.primary.background="#191919"' \
        -o 'window.padding.x=16' -o 'window.padding.y=16' \
        -e bash -c '"$1" pick; printf "%s\n" "$?" > "$2"' \
        files-result "$ROOT/modi/files.sh" "$result" 9>&- >/dev/null 2>&1; then
        read -r status < "$result" || status=1 # Closing the terminal is Back too.
    else
        status=2
    fi
    case $status in
        0|1) return "$status";;
        *) info Files 'Could not open Files or the selected path.' || :; return 1;;
    esac
)
files_pick() (
    cd -- "$HOME" || exit
    args=(fd --hidden --no-ignore --type f --type d --type l --print0)
    while IFS= read -r pattern; do args+=(--exclude "$pattern"); done < <(cfg '.exclude[]')
    selected=$(mktemp "$RUNTIME/files-selected.XXXXXX"); trap 'rm -f -- "$selected"' EXIT
    # NUL delimiters preserve filenames containing newlines. No path is evaluated.
    if FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= FZF_DEFAULT_COMMAND= fzf \
        --read0 --print0 --scheme=path --layout=reverse --border=rounded \
        --prompt='Files › ' --header='Home · Enter opens in VS Code · Esc returns to Menu' \
        --color='bg:#191919,fg:#f8f8f2,bg+:#303030,fg+:#67ffeb,hl:#67ffeb,hl+:#67ffeb,prompt:#67ffeb,border:#67ffeb' \
        --bind='enter:accept,esc:abort,ctrl-c:abort' < <("${args[@]}" .) > "$selected"; then
        IFS= read -r -d '' path < "$selected" || exit 2
        [[ $path == /* ]] || path=$HOME/$path
        [[ -e $path ]] && code -- "$path" || exit 2
    else
        case $? in 1|130) exit 1;; *) exit 2;; esac
    fi
)
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    source "$(dirname -- "$0")/common.sh"
    case ${1:-pick} in pick) files_pick;; *) exit 2;; esac
fi

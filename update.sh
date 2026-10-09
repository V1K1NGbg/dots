#!/usr/bin/env bash
# One-time update from bdbeb61 (the installation before the October 9 changes).
# Run from the updated checkout as your desktop user: bash update.sh

# Keep this list fixed so committing the update does not change what it installs.
UPDATED_CONFIG_FILES=(
    '.config/BetterDiscord/data/stable/settings.json'
    '.config/BetterDiscord/themes/neutron.theme.css'
    '.config/Code - OSS/User/settings.json'
    '.config/Code - OSS/User/transparency.css'
    .config/garden/renderer.c
    .config/gtk-3.0/gtk.css
    .config/hypr/hyprland.lua
    .config/hypr/monitors/monitors.sh
    .config/hypr/scripts/autostart.sh
    .config/hypr/scripts/screenshot.sh
    .config/opencode/AGENTS.md
    .config/opencode/agents/architect.md
    .config/opencode/agents/build.md
    .config/opencode/agents/code-reviewer.md
    .config/opencode/agents/explore.md
    .config/opencode/agents/plan.md
    .config/opencode/agents/research.md
    .config/opencode/agents/security.md
    .config/opencode/agents/verifier.md
    .config/opencode/cli.json
    .config/opencode/opencode.json
    .config/opencode/skills/ponytail/SKILL.md
    .config/rofi/modi/ai-request.sh
    .config/rofi/modi/ai.sh
    .config/rofi/modi/common.sh
    .config/rofi/modi/files.sh
    .config/systemd/user/llama-cpp.service
    .config/themeapply/firefox.sh
    .config/themeapply/firefox/user.js
    .config/themeapply/firefox/userChrome.css
    .config/themeapply/firefox/userContent.css
)
RETIRED_CONFIG_FILE=.config/rofi/modi/ai-request.py

update_files() (
    set -euo pipefail
    umask 077
    local repo=$1 home_dir=$2 path target parent backup temporary=''
    trap 'rm -f -- "$temporary"' EXIT

    for path in "${UPDATED_CONFIG_FILES[@]}" "$RETIRED_CONFIG_FILE"; do
        target=$home_dir/$path
        [[ ! -e $target || -f $target ]] || {
            printf 'Expected a regular file: %s\n' "$target" >&2; exit 1
        }
        parent=$target
        while [[ $parent != "$home_dir" ]]; do
            [[ ! -L $parent ]] || {
                printf 'Refusing symlink: %s\n' "$parent" >&2; exit 1
            }
            parent=${parent%/*}
            [[ ! -e $parent || -d $parent ]] || {
                printf 'Expected a directory: %s\n' "$parent" >&2; exit 1
            }
        done
        [[ $path == "$RETIRED_CONFIG_FILE" || -f $repo/config/$path ]] || {
            printf 'Missing update source: %s\n' "$repo/config/$path" >&2; exit 1
        }
    done

    # Prepare the only generated config before replacing any installed files.
    temporary=$(mktemp)
    jq --arg css "$home_dir/.config/Code - OSS/User/transparency.css" \
        '.["vscode_vibrancy.imports"] = [$css]' \
        "$repo/config/.config/Code - OSS/User/settings.json" > "$temporary"

    mkdir -p "$home_dir/.local/share/archinstaller"
    backup=$(mktemp -d "$home_dir/.local/share/archinstaller/update-20261009.XXXXXXXX")
    : > "$backup/existing.txt"
    : > "$backup/created.txt"
    for path in "${UPDATED_CONFIG_FILES[@]}" "$RETIRED_CONFIG_FILE"; do
        if [[ -f $home_dir/$path ]]; then
            printf '%s\n' "$path" >> "$backup/existing.txt"
        elif [[ $path != "$RETIRED_CONFIG_FILE" ]]; then
            printf '%s\n' "$path" >> "$backup/created.txt"
        fi
    done
    tar -cpf "$backup/files.tar" -C "$home_dir" -T "$backup/existing.txt"
    mv -- "$temporary" "$backup/code-settings.json"
    temporary=''
    printf 'Recovery archive: %s/files.tar\n' "$backup"

    for path in "${UPDATED_CONFIG_FILES[@]}"; do
        target=$home_dir/$path
        mkdir -p -- "${target%/*}"
        temporary=$(mktemp "${target}.XXXXXXXX")
        cp -p -- "$repo/config/$path" "$temporary"
        if [[ $path == '.config/Code - OSS/User/settings.json' ]]; then
            cat "$backup/code-settings.json" > "$temporary"
        fi
        mv -f -- "$temporary" "$target"
        temporary=''
    done
    rm -f -- "$home_dir/$RETIRED_CONFIG_FILE"
    # Garden's build helper compares mtimes against the existing cached binary.
    touch "$home_dir/.config/garden/renderer.c"
)

update_system() (
    set -euo pipefail
    [[ $# == 0 ]] || { echo 'Usage: bash update.sh' >&2; exit 2; }
    [[ $EUID != 0 && $(uname -s) == Linux ]] || {
        echo 'Run as your normal user on the installed Arch Linux desktop, without sudo.' >&2; exit 1
    }
    [[ -t 0 ]] || { echo 'Run in a terminal; Code and Vimium need interactive setup.' >&2; exit 1; }
    [[ ${XDG_CONFIG_HOME:-$HOME/.config} == "$HOME/.config" ]] || {
        echo 'This update expects the installer configuration at ~/.config.' >&2; exit 1
    }
    local repo command running
    repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    for command in sudo pacman paru jq code firefox systemctl pgrep; do
        command -v "$command" >/dev/null || { printf 'Missing command: %s\n' "$command" >&2; exit 1; }
    done
    systemctl --user show-environment >/dev/null
    [[ -f $HOME/.mozilla/firefox/profiles.ini || -f $HOME/.config/mozilla/firefox/profiles.ini ]] || {
        echo 'Open Firefox once, close it, then rerun this update.' >&2; exit 1
    }
    running=0
    pgrep -u "$UID" -f '(^|/)(code|code-oss|Code - OSS|discord|Discord|firefox|nemo|opencode|rofi)([[:space:]]|$)' >/dev/null || running=$?
    [[ $running == 1 ]] || {
        echo 'Close Code, Discord, Firefox, Nemo, OpenCode and Rofi before updating (or check pgrep if none are open).' >&2
        exit 1
    }
    trap 'rc=$?; if ((rc != 0)); then echo "Update incomplete. Fix the reported error and rerun; any file backup path is printed above." >&2; fi' EXIT

    sudo pacman -S --needed imagemagick tesseract tesseract-data-eng tesseract-data-bul
    paru -S --needed localsend
    if pacman -Q kdeconnect >/dev/null 2>&1; then
        sudo pacman -R kdeconnect
    fi
    if systemctl --user is-active --quiet dots-rofi-ai.service; then
        systemctl --user stop dots-rofi-ai.service
    fi
    update_files "$repo" "$HOME"

    # Reuse the same profile migration and interactive editor setup as install.sh.
    source "$repo/install.sh"
    bash "$HOME/.config/themeapply/firefox.sh"
    mark_done firefox_transparency
    bash "$HOME/.config/garden/control.sh" --build
    systemctl --user daemon-reload
    systemctl --user try-restart llama-cpp.service dots-garden.service
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        hyprctl reload
    fi
    install_vscode

    firefox about:addons >/dev/null 2>&1 &
    printf '\nIn Vimium options, export your current settings for recovery, then import:\n  %s/config/vimium-options.json\n' "$repo"
    read -rp 'After importing and saving the Vimium settings, press Enter to finish...'
    printf '\nUpdate complete. Reopen your apps; log out and back in to refresh the whole desktop.\n'
    printf 'New keys: Super+Shift+P / Shift+Print = OCR; Super+Ctrl+P = LocalSend; Super+Ctrl+Shift+P = displays.\n'
)

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    update_system "$@"
fi

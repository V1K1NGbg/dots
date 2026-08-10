#!/usr/bin/env bash

register_phase apps "Applications & accounts"

check_git_identity() {
  [[ $(git config --global user.name 2>/dev/null) == "V1K1NGbg" ]] &&
    [[ $(git config --global user.email 2>/dev/null) == "victor@ilchev.com" ]]
}
install_git_identity() {
  run mkdir -p "$HOME/Documents/GitHub"
  run git config --global user.name "V1K1NGbg"
  run git config --global user.email "victor@ilchev.com"
}

check_gh_auth() { gh auth status >/dev/null 2>&1; }
install_gh_auth() { run gh auth login; }

check_wireguard() { nmcli -t -f TYPE connection show 2>/dev/null | grep -qx wireguard; }
install_wireguard() {
  local source name
  ((NONINTERACTIVE == 0)) || return 2
  read -r -e -p '  Path to WireGuard configuration: ' source
  [[ -f "$source" ]] || return 1
  name=$(basename "$source" .conf)
  run nmcli connection import type wireguard file "$source"
  run nmcli connection modify "$name" connection.autoconnect no
  nmcli connection down "$name" >/dev/null 2>&1 || true
}

check_pcloud() { confirmed pcloud; }
install_pcloud() {
  run mkdir -p "$HOME/Documents/BackUp/screenshots" "$HOME/Documents/PC"
  run pcloud >/dev/null 2>&1 &
  prompt_continue "Log in to pCloud, configure PC sync and BackUp, then continue"
  mark_confirmed pcloud
}

check_discord() { confirmed discord && [[ -d "$HOME/.config/BetterDiscord" ]]; }
install_discord() {
  run discord >/dev/null 2>&1 &
  prompt_continue "Log in to Discord, install BetterDiscord, then continue"
  run mkdir -p "$HOME/.config/BetterDiscord"
  run cp -a "$DOTS_ROOT/.config/BetterDiscord/." "$HOME/.config/BetterDiscord/"
  killall Discord >/dev/null 2>&1 || true
  mark_confirmed discord
}

check_spotify() { confirmed spotify; }
install_spotify() {
  run spotify-launcher >/dev/null 2>&1 &
  prompt_continue "Log in to Spotify and disable song-change notifications"
  killall spotify-launcher >/dev/null 2>&1 || true
  mark_confirmed spotify
}

check_opencode() {
  { command_exists opencode || [[ -x "$HOME/.opencode/bin/opencode" ]]; } &&
    [[ -f "$HOME/.config/opencode/opencode.json" ]]
}
install_opencode() {
  local temp
  temp=$(mktemp)
  run curl --fail --location --output "$temp" https://opencode.ai/install
  ((DRY_RUN)) || bash "$temp"
  rm -f "$temp"
}

check_vscode() { confirmed vscode; }
install_vscode() {
  run code >/dev/null 2>&1 &
  prompt_continue "Sign in to VS Code and wait for settings sync"
  killall code >/dev/null 2>&1 || true
  mark_confirmed vscode
}

check_copyq() { [[ $DESKTOP_PROFILE != awesome ]] || confirmed copyq; }
install_copyq() {
  [[ $DESKTOP_PROFILE == awesome ]] || return 0
  run copyq >/dev/null 2>&1 &
  prompt_continue "Import copyq.cpq and configure the window-under-mouse shortcut"
  killall copyq >/dev/null 2>&1 || true
  mark_confirmed copyq
}

check_firefox() { confirmed firefox; }
install_firefox() {
  run firefox >/dev/null 2>&1 &
  prompt_continue "Sync Firefox and import the current Vimium and Bonjourr files"
  killall firefox >/dev/null 2>&1 || true
  mark_confirmed firefox
}

check_steam() { confirmed steam; }
install_steam() {
  run steam >/dev/null 2>&1 &
  prompt_continue "Log in to Steam and wait for initial setup"
  killall steam >/dev/null 2>&1 || true
  mark_confirmed steam
}

check_nvm() { [[ -s "$HOME/.nvm/nvm.sh" ]]; }
install_nvm() {
  local temp
  temp=$(mktemp)
  run curl --fail --location --output "$temp" \
    https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh
  ((DRY_RUN)) || PROFILE=/dev/null bash "$temp"
  rm -f "$temp"
  if ((DRY_RUN == 0)); then
    # shellcheck disable=SC1091
    source "$HOME/.nvm/nvm.sh"
    nvm install --lts
  fi
}

check_vtop() { command_exists vtop; }
install_vtop() {
  # shellcheck disable=SC1091
  [[ -s "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh"
  run npm install --global vtop
}

register_task git-identity apps "Configure Git identity" check_git_identity install_git_identity "packages" ""
register_task gh-auth apps "Authenticate GitHub CLI" check_gh_auth install_gh_auth "git-identity" "manual"
register_task wireguard apps "Import WireGuard profile" check_wireguard install_wireguard "packages" "manual"
register_task pcloud apps "Configure pCloud" check_pcloud install_pcloud "packages" "manual graphical"
register_task discord apps "Configure Discord" check_discord install_discord "dotfiles" "manual graphical"
register_task spotify apps "Configure Spotify" check_spotify install_spotify "dotfiles" "manual graphical"
register_task opencode apps "Install OpenCode" check_opencode install_opencode "dotfiles" ""
register_task vscode apps "Synchronize VS Code" check_vscode install_vscode "dotfiles" "manual graphical"
register_task copyq apps "Import CopyQ settings (Awesome)" check_copyq install_copyq "dotfiles" "manual graphical"
register_task firefox apps "Configure Firefox" check_firefox install_firefox "dotfiles" "manual graphical"
register_task steam apps "Configure Steam" check_steam install_steam "packages" "manual graphical"
register_task nvm apps "Install NVM and Node LTS" check_nvm install_nvm "packages" ""
register_task vtop apps "Install vtop" check_vtop install_vtop "nvm" ""

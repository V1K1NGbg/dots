#!/usr/bin/env bash

register_phase bootstrap "Bootstrap"

check_arch() { [[ -f /etc/arch-release ]] && command_exists pacman; }
install_arch_check() {
  check_arch || { warn "this installer supports Arch Linux only"; return 1; }
  [[ $EUID -ne 0 ]] || { warn "run as the target user, not root"; return 1; }
}

check_multilib() { grep -q '^\[multilib\]' /etc/pacman.conf 2>/dev/null; }
install_multilib() {
  run sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
  run sudo pacman -Sy
}

check_system_update() {
  [[ -f "$STATE_ROOT/system-update.timestamp" ]] &&
    find "$STATE_ROOT/system-update.timestamp" -mmin -1440 -print -quit 2>/dev/null | grep -q .
}
install_system_update() {
  run sudo pacman -Syu
  ((DRY_RUN)) || date +%s >"$STATE_ROOT/system-update.timestamp"
}

check_paru() { command_exists paru; }
install_paru() {
  local temp
  run sudo pacman -S --needed base-devel git
  temp=$(mktemp -d)
  trap 'rm -rf "$temp"' RETURN
  run git clone https://aur.archlinux.org/paru-git.git "$temp/paru-git"
  if ((DRY_RUN)); then
    log "(cd $temp/paru-git && makepkg -si)"
  else
    (cd "$temp/paru-git" && makepkg -si)
  fi
}

register_task preflight bootstrap "Validate this machine" check_arch install_arch_check "" ""
register_task multilib bootstrap "Enable multilib" check_multilib install_multilib "preflight" "sudo"
register_task system-update bootstrap "Update the system" check_system_update install_system_update "multilib" "sudo"
register_task paru bootstrap "Install Paru" check_paru install_paru "system-update" "sudo"

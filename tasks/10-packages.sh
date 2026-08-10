#!/usr/bin/env bash

register_phase packages "Packages"

read_packages() {
  sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$DOTS_ROOT/config/packages.txt"
}

check_packages() {
  local package
  command_exists pacman || return 1
  while IFS= read -r package; do package_installed "$package" || return 1; done < <(read_packages)
}

install_packages() {
  local -a packages=()
  mapfile -t packages < <(read_packages)
  run paru -S --needed "${packages[@]}"
}

check_monocraft() { fc-list 2>/dev/null | grep -qi 'Monocraft Nerd Font'; }
install_monocraft() {
  local destination="$HOME/.local/share/fonts/Monocraft-nerd-fonts-patched.ttc"
  run mkdir -p "$(dirname "$destination")"
  run curl --fail --location --output "$destination" \
    https://github.com/IdreesInc/Monocraft/releases/download/v4.0/Monocraft-nerd-fonts-patched.ttc
  run fc-cache -f
}

check_picom() { command_exists picom; }
install_picom() {
  local temp
  temp=$(mktemp -d)
  trap 'rm -rf "$temp"' RETURN
  run git clone --depth 1 https://github.com/pijulius/picom.git "$temp/picom"
  if ((DRY_RUN)); then
    log "build picom in $temp/picom"
  else
    meson setup --buildtype=release "$temp/picom/build" "$temp/picom"
    ninja -C "$temp/picom/build"
    sudo ninja -C "$temp/picom/build" install
  fi
}

register_task packages packages "Install package manifest" check_packages install_packages "paru" "sudo"
register_task monocraft packages "Install Monocraft font" check_monocraft install_monocraft "packages" ""
register_task picom packages "Build custom Picom" check_picom install_picom "packages" "sudo"

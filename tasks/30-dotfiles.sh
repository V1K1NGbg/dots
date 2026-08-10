#!/usr/bin/env bash

register_phase dotfiles "Dotfiles & desktop"

manifest_entries() {
  read_manifest "$DOTS_ROOT/config/dotfiles-common.txt"
  read_manifest "$(profile_manifest dotfiles)"
}

source_tree_matches() {
  local source=$1 destination=$2 item relative
  if [[ -f "$source" ]]; then
    [[ -f "$destination" ]] && cmp -s "$source" "$destination"
    return
  fi
  [[ -d "$source" && -d "$destination" ]] || return 1
  while IFS= read -r item; do
    relative=${item#"$source"/}
    if [[ -L "$item" ]]; then
      [[ -L "$destination/$relative" ]] &&
        [[ $(readlink "$item") == "$(readlink "$destination/$relative")" ]] || return 1
    elif [[ -f "$item" ]]; then
      [[ -f "$destination/$relative" ]] && cmp -s "$item" "$destination/$relative" || return 1
    fi
  done < <(find "$source" \( -type f -o -type l \) -print)
}

check_dotfiles() {
  local entry path
  while IFS= read -r path; do
    entry="$DOTS_ROOT/$path"
    source_tree_matches "$entry" "$HOME/$path" || return 1
  done < <(manifest_entries)
  if [[ $DESKTOP_PROFILE == hyprland ]]; then
    cmp -s "$DOTS_ROOT/.config/awesome/wall.jpg" "$HOME/.config/hypr/wall.jpg" || return 1
  fi
}

install_dotfiles() {
  local path source_path destination_path stamp backup_path
  stamp=$(date +%Y%m%d-%H%M%S)
  while IFS= read -r path; do
    source_path="$DOTS_ROOT/$path"
    destination_path="$HOME/$path"
    backup_path="$BACKUP_ROOT/$stamp/$path"
    [[ -e "$source_path" || -L "$source_path" ]] || { warn "missing source: $path"; return 1; }

    if [[ -e "$destination_path" || -L "$destination_path" ]]; then
      run mkdir -p "$(dirname "$backup_path")"
      run cp -a "$destination_path" "$backup_path"
    fi

    if [[ -d "$source_path" ]]; then
      run mkdir -p "$destination_path"
      run cp -a "$source_path/." "$destination_path/"
    else
      run mkdir -p "$(dirname "$destination_path")"
      run cp -a "$source_path" "$destination_path"
    fi
  done < <(manifest_entries)
  if [[ $DESKTOP_PROFILE == awesome ]]; then
    run chmod +x "$HOME/i3lock.sh" "$HOME/.config/awesome/autostart.sh"
  else
    run cp -a "$DOTS_ROOT/.config/awesome/wall.jpg" "$HOME/.config/hypr/wall.jpg"
    run chmod +x "$HOME/.config/hypr/scripts/"*
  fi
}

check_ohmybash() { [[ -r "$HOME/.oh-my-bash/oh-my-bash.sh" ]]; }
install_ohmybash() {
  local temp
  temp=$(mktemp)
  run curl --fail --location --output "$temp" \
    https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh
  ((DRY_RUN)) || OSH="$HOME/.oh-my-bash" bash "$temp" --unattended
  rm -f "$temp"
}

check_nemo() { dconf read /org/nemo/preferences/bulk-rename-tool 2>/dev/null | grep -q bulky; }
install_nemo() { run_shell "dconf load /org/nemo/ < \"$DOTS_ROOT/nemo_config\""; }

check_default_apps() { [[ $(xdg-mime query default text/html 2>/dev/null) == firefox.desktop ]]; }
install_default_apps() {
  local mime
  for mime in text/plain text/markdown application/json; do run xdg-mime default code.desktop "$mime"; done
  for mime in text/html application/xhtml+xml application/pdf; do run xdg-mime default firefox.desktop "$mime"; done
  for mime in video/mp4 video/x-matroska audio/mpeg audio/flac; do run xdg-mime default vlc.desktop "$mime"; done
  for mime in image/png image/jpeg image/webp; do run xdg-mime default gimp.desktop "$mime"; done
  run xdg-mime default nemo.desktop inode/directory
}

check_awesome_const() {
  [[ $DESKTOP_PROFILE == awesome ]] || return 0
  [[ -f "$HOME/.config/awesome/const.lua" ]] &&
    ! grep -q '<APPID>' "$HOME/.config/awesome/const.lua"
}
install_awesome_const() {
  local source
  [[ $DESKTOP_PROFILE == awesome ]] || return 0
  ((NONINTERACTIVE == 0)) || return 2
  read -r -e -p '  Path to private Awesome const.lua: ' source
  [[ -f "$source" ]] || { warn "file not found: $source"; return 1; }
  grep -q 'return const' "$source" || { warn "not a valid const.lua"; return 1; }
  run install -D -m 0600 "$source" "$HOME/.config/awesome/const.lua"
}

check_desktop_profile() {
  [[ $(recorded_desktop_profile 2>/dev/null) == "$DESKTOP_PROFILE" ]] &&
    check_packages && check_dotfiles
}
install_desktop_profile() { record_desktop_profile "$DESKTOP_PROFILE"; }

register_task ohmybash dotfiles "Install Oh My Bash" check_ohmybash install_ohmybash "packages" ""
register_task dotfiles dotfiles "Install managed dotfiles" check_dotfiles install_dotfiles "packages monocraft ohmybash" ""
register_task nemo dotfiles "Import Nemo preferences" check_nemo install_nemo "dotfiles" "graphical"
register_task default-apps dotfiles "Set default applications" check_default_apps install_default_apps "dotfiles" "graphical"
register_task awesome-const dotfiles "Install Awesome weather config" check_awesome_const install_awesome_const "dotfiles" "manual"
register_task desktop-profile dotfiles "Activate selected desktop profile" check_desktop_profile install_desktop_profile "dotfiles picom" ""

#!/usr/bin/env bash

set -Eeuo pipefail

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE=""
APPLY=0

while (($#)); do
  case $1 in
    --apply) APPLY=1 ;;
    --desktop)
      [[ $# -ge 2 ]] || { printf '%s\n' '--desktop requires awesome or hyprland' >&2; exit 2; }
      PROFILE=$2
      shift
      ;;
    *) printf 'Usage: ./backup.sh [--apply] [--desktop awesome|hyprland]\n' >&2; exit 2 ;;
  esac
  shift
done

if [[ -z $PROFILE && -r ${XDG_STATE_HOME:-"$HOME/.local/state"}/dots/desktop-profile ]]; then
  IFS= read -r PROFILE <"${XDG_STATE_HOME:-"$HOME/.local/state"}/dots/desktop-profile"
fi
PROFILE=${PROFILE:-hyprland}
[[ $PROFILE == awesome || $PROFILE == hyprland ]] || { printf 'Invalid desktop profile: %s\n' "$PROFILE" >&2; exit 2; }

while IFS= read -r path; do
  [[ -n "$path" && $path != \#* ]] || continue
  source_path="$HOME/$path"
  destination_path="$DOTS_ROOT/$path"
  [[ -e "$source_path" || -L "$source_path" ]] || continue

  if ((APPLY)); then
    printf 'Updating %s\n' "$path"
    mkdir -p "$(dirname "$destination_path")"
    if [[ -d "$source_path" ]]; then
      mkdir -p "$destination_path"
      cp -a "$source_path/." "$destination_path/"
    else
      cp -a "$source_path" "$destination_path"
    fi
  elif [[ -e "$destination_path" ]] && diff -qr "$source_path" "$destination_path" >/dev/null 2>&1; then
    printf 'unchanged  %s\n' "$path"
  else
    printf 'would update %s\n' "$path"
  fi
done < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' \
  "$DOTS_ROOT/config/dotfiles-common.txt" "$DOTS_ROOT/config/dotfiles-$PROFILE.txt")

if ((APPLY)); then
  dconf dump /org/nemo/ >"$DOTS_ROOT/nemo_config"
  printf 'Nemo preferences exported. Private ignored files remain untracked.\n'
else
  printf '\nDry run only. Use --apply to copy the listed changes.\n'
fi

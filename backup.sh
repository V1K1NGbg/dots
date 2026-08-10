#!/usr/bin/env bash

set -Eeuo pipefail

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$DOTS_ROOT/config/dotfiles.txt"
APPLY=0

if [[ ${1:-} == --apply ]]; then
  APPLY=1
elif [[ $# -gt 0 ]]; then
  printf 'Usage: ./backup.sh [--apply]\n' >&2
  exit 2
fi

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
done <"$MANIFEST"

if ((APPLY)); then
  dconf dump /org/nemo/ >"$DOTS_ROOT/nemo_config"
  printf 'Nemo preferences exported. Private ignored files remain untracked.\n'
else
  printf '\nDry run only. Use --apply to copy the listed changes.\n'
fi

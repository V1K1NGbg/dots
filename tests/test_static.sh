#!/usr/bin/env bash

set -Eeuo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while IFS= read -r file; do
  bash -n "$file"
done < <(find "$TEST_ROOT" -type f \( -name '*.sh' -o -path '*/hypr/scripts/*' \) \
  -not -path '*/.git/*' -print)

if command -v luac >/dev/null 2>&1; then
  luac -p "$TEST_ROOT/.config/hypr/hyprland.lua"
fi

for profile in awesome hyprland; do
  while IFS= read -r path; do
    [[ $path != /* && $path != *'..'* ]]
    [[ -e "$TEST_ROOT/$path" || -L "$TEST_ROOT/$path" ]]
  done < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$TEST_ROOT/config/dotfiles-$profile.txt")
done

for manifest in "$TEST_ROOT"/config/packages-*.txt "$TEST_ROOT"/config/dotfiles-*.txt; do
  duplicates=$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$manifest" | sort | uniq -d)
  [[ -z $duplicates ]] || {
    printf 'duplicate entries in %s:\n%s\n' "$manifest" "$duplicates" >&2
    exit 1
  }
done

printf 'static configuration checks passed\n'

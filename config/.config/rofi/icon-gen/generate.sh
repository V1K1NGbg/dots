#!/bin/bash
# Fetch pinned SVG sources, then write finished, tinted icons to icons/.
set -euo pipefail
# Edit this list to generate more Lucide icons. Names match lucide.dev/icons.
ICONS=(
    layout-grid folder-search bot alarm-clock music volume-2
    panels-top-left calculator clipboard spell-check wifi bluetooth
    power zap
)
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
config=$(jq -e . "${ROFI_SETTINGS:-$root/settings.json}")
color=$(jq -r '.icon_color' <<<"$config")
[[ $color =~ ^#[a-fA-F0-9]{6}$ ]] || { printf 'icon_color must be #RRGGBB\n' >&2; exit 1; }
names=("$@")
if ((${#names[@]}==0)); then
    # Include personal page mappings as well, so deployment preserves overrides.
    while IFS= read -r name; do names+=("$name"); done < <({ printf '%s\n' "${ICONS[@]}"; jq -r '.icons[]' <<<"$config"; } | sort -u)
fi
stage=$(mktemp -d); trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$root/icon-gen/icons"
valid_svg() { [[ -s $1 ]] && grep -q '<svg' "$1" && grep -q 'fill="none"' "$1"; }
for name in "${names[@]}"; do
    [[ $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { printf 'Invalid icon name: %s\n' "$name" >&2; exit 1; }
    printf 'Fetching %s\n' "$name"
    curl -fsSL --max-time 20 "https://raw.githubusercontent.com/lucide-icons/lucide/0.468.0/icons/$name.svg" -o "$stage/$name.svg"
    valid_svg "$stage/$name.svg" || { printf 'Invalid SVG: %s\n' "$name" >&2; exit 1; }
    sed "s/currentColor/$color/g" "$stage/$name.svg" > "$stage/$name.rendered"
done
# Finish every download/render before replacing any installed icon.
for name in "${names[@]}"; do
    cp "$stage/$name.rendered" "$root/icon-gen/icons/$name.svg"
done
printf 'Generated %s transparent icons in %s/icon-gen/icons\n' "${#names[@]}" "$root"

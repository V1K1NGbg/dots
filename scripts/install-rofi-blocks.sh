#!/usr/bin/env bash
# Optional user-local installation when sudo/paru is unavailable.
# The regular install.sh uses the rofi-blocks-git AUR package instead.
set -euo pipefail
revision=026073dc5d0ab695c53d85f39da986aa06e16f5b
for command in git gcc pkg-config; do command -v "$command" >/dev/null; done
pkg-config --exists glib-2.0 gmodule-2.0 json-glib-1.0 cairo rofi
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
git -C "$stage" init -q
git -C "$stage" fetch -q --depth 1 https://github.com/OmarCastro/rofi-blocks "$revision"
git -C "$stage" checkout -q --detach FETCH_HEAD
[[ $(git -C "$stage" rev-parse HEAD) == "$revision" ]]
# Same source list and link options as upstream meson.build.
read -r -a flags <<< "$(pkg-config --cflags --libs glib-2.0 gmodule-2.0 json-glib-1.0 cairo rofi)"
gcc -shared -fPIC -o "$stage/blocks.so" \
    "$stage/src/blocks.c" "$stage/src/blocks_mode_data.c" \
    "$stage/src/json_glib_extensions.c" "$stage/src/page_data.c" \
    "$stage/src/render_state.c" "$stage/src/string_utils.c" \
    "${flags[@]}" -Wl,--unresolved-symbols=ignore-all
target=${XDG_DATA_HOME:-$HOME/.local/share}/rofi/plugins
mkdir -p "$target"
[[ ! -f $target/blocks.so ]] || cp -p "$target/blocks.so" "$target/blocks.so.backup-$(date +%Y%m%d-%H%M%S)"
install -m 755 "$stage/blocks.so" "$target/blocks.so"
printf 'Installed rofi-blocks %s for rofi %s in %s\n' "$revision" "$(pkg-config --modversion rofi)" "$target"

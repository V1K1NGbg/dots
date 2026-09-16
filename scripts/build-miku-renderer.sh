#!/usr/bin/env bash
# Build only Miku's renderer; never replace the system package.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
revision=787b5a072a9d1439af26fb2d247ba0822498023c
source=${1:-https://github.com/CluelessCatBurger/wl_shimeji.git}
data=${XDG_DATA_HOME:-$HOME/.local/share}/dots-miku
mkdir -p "$data"
stamp=$(sha256sum "$root/patches/wl-shimeji-drag.patch" | cut -d' ' -f1)
if [[ -x $data/bin/shimeji-overlayd && -f $data/bin/renderer.sha256 ]] &&
   [[ $(cat "$data/bin/renderer.sha256") == "$revision $stamp" ]]; then
    echo 'Miku renderer already built.'
    exit 0
fi
scratch=$(mktemp -d "$data/build.XXXXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
git clone --no-checkout "$source" "$scratch/source"
git -C "$scratch/source" checkout --detach "$revision"
git -C "$scratch/source" submodule update --init src/third_party/json.h src/third_party/qoi
git -C "$scratch/source" apply "$root/patches/wl-shimeji-drag.patch"
make -C "$scratch/source" -j2 build/shimeji-overlayd
mkdir -p "$data/bin"
install -m755 "$scratch/source/build/shimeji-overlayd" "$data/bin/shimeji-overlayd.new"
if [[ -f $data/bin/shimeji-overlayd ]]; then
    cp -p "$data/bin/shimeji-overlayd" "$data/bin/shimeji-overlayd.previous"
fi
mv "$data/bin/shimeji-overlayd.new" "$data/bin/shimeji-overlayd"
printf '%s %s\n' "$revision" "$stamp" > "$data/bin/renderer.sha256"
echo "Miku renderer installed: $data/bin/shimeji-overlayd"

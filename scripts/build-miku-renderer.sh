#!/bin/bash
# Build only Miku's renderer; never replace the system package.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
revision=787b5a072a9d1439af26fb2d247ba0822498023c
source=${1:-https://github.com/CluelessCatBurger/wl_shimeji.git}
data=${XDG_DATA_HOME:-$HOME/.local/share}/dots-miku
mkdir -p "$data"
if [[ -e $data/bin || -L $data/bin ]]; then
    [[ ! -L $data/bin && -x $data/bin/shimeji-overlayd ]] || {
        echo "Inspect incomplete or symlinked renderer directory: $data/bin" >&2
        exit 1
    }
    echo 'Miku renderer already installed; leaving it untouched.'
    exit 0
fi
scratch=$(mktemp -d "$data/build.XXXXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
git clone --no-checkout "$source" "$scratch/source"
git -C "$scratch/source" checkout --detach "$revision"
git -C "$scratch/source" submodule update --init src/third_party/json.h src/third_party/qoi
git -C "$scratch/source" apply "$root/patches/wl-shimeji-drag.patch"
make -C "$scratch/source" -j2 build/shimeji-overlayd
mkdir "$scratch/bin"
install -m755 "$scratch/source/build/shimeji-overlayd" "$scratch/bin/shimeji-overlayd"
mv "$scratch/bin" "$data/bin"
echo "Miku renderer installed: $data/bin/shimeji-overlayd"

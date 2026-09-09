#!/usr/bin/env bash
# Import settings from older layouts. Run before copying the Rofi tree.
# Existing new-format settings and state always win; original files are retained.
set -euo pipefail
umask 077
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
source_config=$(cd -- "$(dirname -- "$0")/../.config" && pwd)
state_home=${XDG_STATE_HOME:-$HOME/.local/state}
mkdir -p "$config_home/rofi" "$state_home/dots-utils"
for previous in utils desktop-utils dots-desktop dots-rofi; do
    if [[ ! -f $state_home/dots-utils/clocks.json && -f $state_home/$previous/clocks.json ]]; then
        jq -e '.items|type=="array"' "$state_home/$previous/clocks.json" >/dev/null
        cp -p "$state_home/$previous/clocks.json" "$state_home/dots-utils/clocks.json"
    fi
    cache_home=${XDG_CACHE_HOME:-$HOME/.cache}
    mkdir -p "$cache_home/dots-utils"
    for name in weather; do
        if [[ ! -f $cache_home/dots-utils/$name && -f $cache_home/$previous/$name ]]; then
            cp -p "$cache_home/$previous/$name" "$cache_home/dots-utils/$name"
        fi
    done
done
# Preserve existing rendered icons when consolidating the icon-generator folder.
if [[ -d $config_home/rofi/icons ]]; then
    mkdir -p "$config_home/rofi/icon-gen/icons"
    for file in "$config_home/rofi/icons/"*; do
        [[ -f $file ]] || continue
        target=$config_home/rofi/icon-gen/icons/${file##*/}
        [[ -f $target ]] || cp -p "$file" "$target"
    done
fi
# One settings file; explicit Rofi values win over the previous utility settings.
legacy='{}'
for previous in rofi/utils dots-utils utils desktop-utils dots-desktop; do
    if [[ -f $config_home/$previous/settings.json ]]; then
        legacy=$(jq 'with_entries(select(.key=="weather" or .key=="sound" or .key=="exclude"))' "$config_home/$previous/settings.json")
        break
    fi
done
target=$config_home/rofi/settings.json
current='{}'
if [[ -f $target ]]; then current=$(cat "$target")
elif [[ -f $config_home/rofi/hub.json ]]; then current=$(cat "$config_home/rofi/hub.json"); fi
temporary=$(mktemp "$target.XXXXXX")
if jq -s --arg old "$config_home/rofi/utils/sounds/" --arg new "$config_home/rofi/sounds/" '
    .[0] * .[1] * .[2] | del(.refresh_seconds) |
    .icons.run=(.icons.run//.icons.apps//"layout-grid") | del(.icons.apps,.icons.tray,.icons.keys) |
    if (.sound|type)=="string" and (.sound|startswith($old)) then .sound=($new+(.sound|ltrimstr($old))) else . end
    ' "$source_config/rofi/settings.json" <(printf '%s' "$legacy") <(printf '%s' "$current") > "$temporary"; then
    mv -f -- "$temporary" "$target"
else rm -f -- "$temporary"; exit 1; fi
# Keep custom sounds when moving the asset directory.
if [[ -d $config_home/rofi/utils/sounds ]]; then
    mkdir -p "$config_home/rofi/sounds"
    for sound in "$config_home/rofi/utils/sounds/"*; do
        [[ -f $sound ]] || continue
        [[ -f $config_home/rofi/sounds/${sound##*/} ]] || cp -p "$sound" "$config_home/rofi/sounds/"
    done
fi
# Keep locally added SVG sources available for offline generation.
if [[ -d $config_home/rofi/hub/icons ]]; then
    mkdir -p "$config_home/rofi/icon-gen/sources"
    for file in "$config_home/rofi/hub/icons/"*.svg; do
        [[ -f $file ]] || continue
        target=$config_home/rofi/icon-gen/sources/${file##*/}
        [[ -f $target ]] || cp -p "$file" "$target"
    done
fi

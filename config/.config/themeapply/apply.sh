#!/usr/bin/env bash
# Installed runtime: repair customizations after a package transaction.
set -euo pipefail
umask 077

app=${1:?Usage: apply.sh discord|spotify}
case $app in discord|spotify) ;; *) echo "Unsupported app theme: $app (use discord or spotify)" >&2; exit 2 ;; esac
config=${XDG_CONFIG_HOME:-$HOME/.config}
data=${XDG_DATA_HOME:-$HOME/.local/share}
state=${XDG_STATE_HOME:-$HOME/.local/state}/themeapply
mkdir -p "$state"
exec 9>"$state/$app.lock"
flock -n 9 || exit 0

if [[ $app == discord ]]; then
    # The current native Discord updater keeps each release in the user's home.
    resources=$(find "$config/discord" -maxdepth 3 -type f \
        \( -name app.asar -o -name betterdiscord.app.asar \) -printf '%h\n' 2>/dev/null |
        sort -Vu | tail -n 1) || true
    [[ -n $resources ]] || { echo 'Open Discord once, then rerun its theme service.' >&2; exit 1; }
    [[ -f $resources/app.asar || ! -f $resources/app/index.js ||
       ! -f $config/BetterDiscord/data/betterdiscord.asar ]] || exit 0
    repo=BetterDiscord/cli
    asset_pattern='^bdcli_[0-9.]+_linux_amd64\.tar\.gz$'
else
    # The repository package updates the launcher; it owns the actual client update.
    if pgrep -u "$UID" -f '(^|/)spotify-launcher([[:space:]]|$)' >/dev/null; then
        echo 'Spotify launcher is busy; rerun the theme service when it finishes.' >&2
        exit 1
    fi
    spotify-launcher --check-update --no-exec
    spotify=$data/spotify-launcher/install/usr/share/spotify
    target=$spotify/spotify
    fingerprint=$(stat -c '%i:%s:%Y:%Z' "$target")
    [[ -f $spotify/Apps/xpui.spa || ! -f $state/spotify.applied ||
       $(cat "$state/spotify.applied") != "$fingerprint" ]] || exit 0
    # Spicetify reads its version from prefs, which may still describe the old client.
    # Give it the installed binary's version without changing the user's preferences.
    version=$("$target" --version)
    [[ $version =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[[:alnum:]]+) ]] || {
        echo 'Cannot determine the installed Spotify version.' >&2
        exit 1
    }
    version=${BASH_REMATCH[1]}
    repo=spicetify/cli
    asset_pattern='^spicetify-[0-9.]+-linux-amd64\.tar\.gz$'
fi

[[ $(uname -m) == x86_64 ]] || { echo 'App themes require x86_64 Linux.' >&2; exit 1; }

scratch=$(mktemp -d "$state/download.XXXXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
curl --fail --location --silent --show-error --max-time 60 \
    "https://api.github.com/repos/$repo/releases/latest" > "$scratch/release.json"
read -r url digest < <(jq -er --arg pattern "$asset_pattern" \
    '.assets[] | select(.name | test($pattern)) | [.browser_download_url, .digest] | @tsv' \
    "$scratch/release.json")
[[ $url == "https://github.com/$repo/releases/download/"* &&
   $digest =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'Invalid release asset or checksum.' >&2; exit 1; }
curl --fail --location --silent --show-error --max-time 180 "$url" -o "$scratch/tool.tar.gz"
printf '%s  %s\n' "${digest#sha256:}" "$scratch/tool.tar.gz" | sha256sum --check --status
mkdir "$scratch/tool"
tar -xzf "$scratch/tool.tar.gz" --no-same-owner -C "$scratch/tool"
tool=$data/themeapply/$app
mkdir -p "$tool"
cp -R "$scratch/tool/." "$tool/"

if [[ $app == discord ]]; then
    "$tool/bdcli" install --path "$resources"
else
    printf 'app.last-launched-version="%s"\n' "$version" > "$scratch/prefs"
    trap '
        status=$?
        "$tool/spicetify" config prefs_path "$config/spotify/prefs" >/dev/null || status=1
        rm -rf -- "$scratch"
        exit "$status"
    ' EXIT
    "$tool/spicetify" config spotify_path "$spotify" prefs_path "$scratch/prefs" \
        current_theme Ziro color_scheme dots inject_css 1 replace_colors 1 \
        check_spicetify_update 0
    if [[ -f $spotify/Apps/xpui.spa ]]; then
        "$tool/spicetify" backup apply --no-restart
    else
        # Retry an interrupted apply using its backup; never restore an old client.
        "$tool/spicetify" apply --no-restart
    fi
    [[ -d $spotify/Apps/xpui && ! -f $spotify/Apps/xpui.spa ]]
    printf '%s\n' "$fingerprint" > "$state/spotify.applied"
    echo 'Spotify theme applied; an already open window uses it on its next restart.'
fi

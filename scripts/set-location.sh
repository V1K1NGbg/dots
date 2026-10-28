#!/usr/bin/env bash
# Set system timezone and Rofi weather location by picking a city.
set -Eeuo pipefail

usage() {
    cat <<'EOF'
Usage: sudo ./scripts/set-location.sh [LOCATION]

Locations:
  amsterdam    Europe/Amsterdam    52.37, 4.90
  sofia        Europe/Sofia        42.70, 23.32
  dublin       Europe/Dublin       53.35, -6.26

Updates /etc/localtime and ~/.config/rofi/settings.json.
If LOCATION is omitted, prints the list.
EOF
}

LOCATIONS=(
    "amsterdam:Europe/Amsterdam:Amsterdam:52.3676:4.9041"
    "sofia:Europe/Sofia:Sofia:42.6977:23.3219"
    "dublin:Europe/Dublin:Dublin:53.3498:-6.2603"
)

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

key=${1-}
if [[ -z "$key" ]]; then
    usage
    exit 0
fi

[[ $EUID -eq 0 ]] || fail "run as root"

match=""
for entry in "${LOCATIONS[@]}"; do
    if [[ "${entry%%:*}" == "$key" ]]; then
        match=$entry
        break
    fi
done
[[ -n "$match" ]] || fail "unknown location '$key' (run without args for the list)"

IFS=: read -r _ timezone city latitude longitude <<<"$match"

[[ -e "/usr/share/zoneinfo/$timezone" ]] \
    || fail "timezone '$timezone' not found under /usr/share/zoneinfo"

command -v jq >/dev/null \
    || fail "jq is required to update rofi settings"

# Under sudo, $HOME points at /root; resolve the invoking user's real home instead.
if [[ -n ${SUDO_USER:-} ]]; then
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    [[ -n $user_home ]] || fail "could not determine home for $SUDO_USER"
else
    user_home=$HOME
fi
ROFI_SETTINGS="${XDG_CONFIG_HOME:-$user_home/.config}/rofi/settings.json"
[[ -r $ROFI_SETTINGS ]] \
    || fail "rofi settings not found at $ROFI_SETTINGS"

ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
hwclock --systohc

# Capture ownership so the rewrite (running as root) doesn't lock the file
# away from the invoking user. If stat fails, leave the new file's perms alone.
original_mode=$(stat -c %a "$ROFI_SETTINGS" 2>/dev/null) || original_mode=
original_owner=$(stat -c %u:%g "$ROFI_SETTINGS" 2>/dev/null) || original_owner=

tmp=$(mktemp)
if ! jq --arg city "$city" --argjson lat "$latitude" --argjson lon "$longitude" \
        '.weather.city = $city | .weather.latitude = $lat | .weather.longitude = $lon' \
        "$ROFI_SETTINGS" > "$tmp"; then
    rm -f -- "$tmp"
    fail "failed to update $ROFI_SETTINGS (jq exited non-zero)"
fi
mv -- "$tmp" "$ROFI_SETTINGS"

# Restore original mode and owner so the user can still read the file.
[[ -n $original_mode ]] && chmod -- "$original_mode" "$ROFI_SETTINGS"
[[ -n $original_owner ]] && chown -- "$original_owner" "$ROFI_SETTINGS"

# Drop the cached weather so Rofi refetches for the new location instead of
# serving the previous city's data from its 15-minute TTL cache.
weather_cache="${XDG_CACHE_HOME:-$user_home/.cache}/dots-utils/weather"
[[ -f $weather_cache ]] && rm -f -- "$weather_cache"

printf 'Timezone: %s\nRofi:     %s (%s, %s)\n' "$timezone" "$city" "$latitude" "$longitude"

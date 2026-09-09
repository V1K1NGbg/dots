#!/usr/bin/env bash
# Apply only the tested lock-screen config; the next lock uses it.
set -euo pipefail
repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
source_config=$repo/.config/hypr/hyprlock.conf
grep -Eq 'pam:enabled[[:space:]]*=[[:space:]]*true' "$source_config"
grep -Eq 'fingerprint:enabled[[:space:]]*=[[:space:]]*true' "$source_config"
[[ -r /etc/pam.d/login ]] || { printf 'Missing Arch password PAM service: /etc/pam.d/login\n' >&2; exit 1; }
backup=$(mktemp -d "$HOME/dots-dev/lockscreen-backup.XXXXXXXX")
if [[ -f $HOME/.config/hypr/hyprlock.conf ]]; then
    cp -p "$HOME/.config/hypr/hyprlock.conf" "$backup/hyprlock.conf"
fi
mkdir -p "$HOME/.config/hypr"
install -m 644 "$source_config" "$HOME/.config/hypr/hyprlock.conf"
printf 'Backup: %s\nApplied lock-screen configuration; press Super+L to try it.\n' "$backup"

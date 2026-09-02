#!/usr/bin/env bash

set -Eeuo pipefail

VPN_CONFIG=""
USER_NAME=$(id -un)

usage() {
    cat <<'EOF'
Usage: ./post-install.sh [--vpn /absolute/path/to/wireguard.conf]

Run this as the installed desktop user after the first reboot. It imports a
WireGuard profile, authenticates GitHub CLI, enrolls and verifies a fingerprint,
and opens pCloud for account setup. Type "skip" at the VPN prompt if no profile
should be imported yet.
EOF
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

step() {
    printf '\n==> %s\n' "$*"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vpn)
            [[ $# -ge 2 ]] || fail "--vpn requires an absolute file path"
            VPN_CONFIG=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "unknown argument: $1"
            ;;
    esac
done

[[ $EUID -ne 0 ]] || fail "run this as victor, not as root; sudo is used only when required"
[[ "$USER_NAME" == "victor" ]] || fail "this configuration expects the victor account"

for command_name in gh nmcli fprintd-enroll fprintd-list fprintd-verify pcloud sudo; do
    command -v "$command_name" >/dev/null || fail "required command not found: $command_name"
done

step "WireGuard VPN"
while true; do
    if [[ -z "$VPN_CONFIG" ]]; then
        read -r -e -p "Absolute WireGuard config path (or 'skip'): " VPN_CONFIG
    fi
    if [[ "$VPN_CONFIG" == "skip" ]]; then
        printf 'WireGuard import skipped. Re-run this script when the file is available.\n'
        break
    elif [[ "$VPN_CONFIG" != /* ]]; then
        printf 'Enter an absolute path beginning with /.\n' >&2
        VPN_CONFIG=""
    elif [[ ! -f "$VPN_CONFIG" || ! -r "$VPN_CONFIG" ]]; then
        printf 'That is not a readable regular file.\n' >&2
        VPN_CONFIG=""
    else
        break
    fi
done

if [[ -n "$VPN_CONFIG" && "$VPN_CONFIG" != "skip" ]]; then
    connection_name=$(basename -- "$VPN_CONFIG")
    connection_name=${connection_name%.conf}

    if nmcli -g NAME connection show | grep -Fxq -- "$connection_name"; then
        read -r -p "Connection '$connection_name' exists. Replace it? [y/N] " replace_vpn
        if [[ "$replace_vpn" =~ ^[Yy]$ ]]; then
            sudo nmcli connection delete "$connection_name"
        else
            printf 'Keeping the existing connection; import skipped.\n'
            VPN_CONFIG="skip"
        fi
    fi

    if [[ "$VPN_CONFIG" != "skip" ]]; then
        sudo nmcli connection import type wireguard file "$VPN_CONFIG"
        read -r -p "Activate '$connection_name' now? [Y/n] " activate_vpn
        if [[ ! "$activate_vpn" =~ ^[Nn]$ ]]; then
            sudo nmcli connection up "$connection_name"
        fi
    fi
fi

step "GitHub CLI authentication"
if gh auth status >/dev/null 2>&1; then
    gh auth status
    printf 'GitHub CLI is already authenticated.\n'
else
    gh auth login
fi

step "Fingerprint enrollment"
fingerprint_list=$(fprintd-list "$USER_NAME" 2>&1 || true)
printf '%s\n' "$fingerprint_list"

if grep -q 'right-index-finger' <<<"$fingerprint_list"; then
    printf 'A right index fingerprint is already enrolled.\n'
else
    printf 'Follow the prompts and repeatedly touch the fingerprint sensor.\n'
    if ! fprintd-enroll --finger right-index-finger "$USER_NAME"; then
        printf '\nFingerprint enrollment failed. Detected USB devices:\n' >&2
        if command -v lsusb >/dev/null; then
            lsusb >&2
        else
            printf '(lsusb is unavailable)\n' >&2
        fi
        printf '%s\n' \
            'The reader may need a hardware-specific libfprint TOD driver.' \
            'Password authentication remains available; adjust services.fprintd.tod and re-run.' >&2
    else
        printf 'Touch the sensor once more to verify enrollment.\n'
        fprintd-verify --finger right-index-finger "$USER_NAME" \
            || printf 'Verification failed; re-run enrollment if necessary.\n' >&2
    fi
fi

if grep -q pam_fprintd /etc/pam.d/sudo && grep -q pam_fprintd /etc/pam.d/hyprlock; then
    printf 'Fingerprint PAM is active for sudo and Hyprlock.\n'
else
    printf '%s\n' \
        'WARNING: fingerprint PAM is not active for both sudo and Hyprlock yet. Rebuild first:' \
        '  sudo nixos-rebuild switch --flake ~/dots#laptop' >&2
fi

step "pCloud account setup"
if [[ -z ${WAYLAND_DISPLAY:-} && -z ${DISPLAY:-} ]]; then
    printf '%s\n' 'No graphical session detected. Log into Hyprland and run pcloud to finish setup.' >&2
elif pgrep -u "$UID" -x pcloud >/dev/null 2>&1; then
    printf 'pCloud is already running. Finish sign-in in its window.\n'
else
    state_directory=${XDG_STATE_HOME:-$HOME/.local/state}
    mkdir -p "$state_directory"
    pcloud >"$state_directory/pcloud-setup.log" 2>&1 &
    disown
    printf 'pCloud has been opened. Complete sign-in and choose its sync settings in the GUI.\n'
fi

printf '\nPost-install workflow finished. Password fallback remains enabled everywhere.\n'

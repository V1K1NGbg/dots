#!/usr/bin/env bash

set -Eeuo pipefail

readonly USER_NAME="victor"
readonly HOST_NAME="viking"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
TARGET_DISK=""
REBOOT_AFTER_INSTALL=1
LUKS_PASSWORD=""
USER_PASSWORD=""
INSTALL_MOUNTS_ACTIVE=0
CRYPTROOT_OPEN=0

usage() {
    cat <<'EOF'
Usage: sudo ./install.sh [--disk /dev/DEVICE] [--no-reboot]

The target disk is completely erased. If --disk is omitted, the script lists
physical disks and asks for one. The only other inputs are the LUKS passphrase,
the victor account password, and the destructive-action confirmation.
EOF
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

prompt_password() {
    local label=$1
    local destination=$2
    local first second

    while true; do
        read -r -s -p "$label: " first
        printf '\n'
        [[ -n "$first" ]] || {
            printf 'The password cannot be empty.\n' >&2
            continue
        }
        read -r -s -p "Confirm $label: " second
        printf '\n'
        [[ "$first" == "$second" ]] || {
            printf 'The passwords do not match.\n' >&2
            continue
        }
        printf -v "$destination" '%s' "$first"
        return
    done
}

clear_secrets() {
    LUKS_PASSWORD=""
    USER_PASSWORD=""
}

on_exit() {
    local status=$?

    clear_secrets
    if [[ $status -ne 0 ]]; then
        printf '\nInstallation failed. Filesystem capacity at failure:\n' >&2
        df -h / /nix /nix/.rw-store /mnt /mnt/nix /mnt/boot 2>/dev/null >&2 || true
        printf '\nInode capacity at failure:\n' >&2
        df -i / /nix /nix/.rw-store /mnt /mnt/nix /mnt/boot 2>/dev/null >&2 || true

        if [[ $INSTALL_MOUNTS_ACTIVE -eq 1 ]]; then
            printf '\nUnmounting the incomplete target installation...\n' >&2
            if umount -R /mnt; then
                INSTALL_MOUNTS_ACTIVE=0
            else
                printf 'WARNING: /mnt is busy; leave /mnt and run: sudo umount -R /mnt\n' >&2
            fi
        fi
        if [[ $CRYPTROOT_OPEN -eq 1 && $INSTALL_MOUNTS_ACTIVE -eq 0 ]]; then
            cryptsetup close cryptroot \
                || printf 'WARNING: run: sudo cryptsetup close cryptroot\n' >&2
        fi
    fi

    return "$status"
}
trap on_exit EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --disk)
            [[ $# -ge 2 ]] || fail "--disk requires a device path"
            TARGET_DISK=$2
            shift 2
            ;;
        --no-reboot)
            REBOOT_AFTER_INSTALL=0
            shift
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

[[ $EUID -eq 0 ]] || fail "run this installer as root"
[[ -d /sys/firmware/efi ]] || fail "boot the NixOS USB in UEFI mode"
[[ -f "$SCRIPT_DIR/flake.nix" ]] || fail "flake.nix is missing beside install.sh"

required_commands=(
    awk blkid btrfs cryptsetup curl grep lsblk mkfs.btrfs mkfs.fat
    df mount nix nixos-enter nixos-generate-config nixos-install parted
    partprobe sed tar udevadm umount
)
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null || fail "required command not found: $command_name"
done

if ! curl --silent --show-error --fail --head https://cache.nixos.org/ >/dev/null; then
    printf 'Network access is required. Opening NetworkManager now.\n'
    nmtui
    curl --silent --show-error --fail --head https://cache.nixos.org/ >/dev/null \
        || fail "network access is still unavailable"
fi

if [[ -z "$TARGET_DISK" ]]; then
    printf 'Available physical disks:\n'
    lsblk -dnpo NAME,SIZE,MODEL,TYPE | awk '$4 == "disk"'
    read -r -p "Target disk (for example /dev/nvme0n1): " TARGET_DISK
fi

[[ -b "$TARGET_DISK" ]] || fail "not a block device: $TARGET_DISK"
[[ "$(lsblk -dno TYPE "$TARGET_DISK")" == "disk" ]] \
    || fail "target must be a whole disk, not a partition"

mounted_paths=$(lsblk -nrpo MOUNTPOINT "$TARGET_DISK" | sed '/^$/d')
[[ -z "$mounted_paths" ]] \
    || fail "the target disk has mounted filesystems; unmount them first: $mounted_paths"

if [[ -e /dev/mapper/cryptroot ]]; then
    printf 'Current target device tree:\n' >&2
    lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$TARGET_DISK" >&2
    fail "cryptroot is still open; reboot the live USB or close it before retrying"
fi

active_holders=$(
    lsblk -nrpo NAME,TYPE,MOUNTPOINTS "$TARGET_DISK" \
        | awk 'NR > 1 && ($2 != "part" || NF > 2)'
)
if [[ -n "$active_holders" ]]; then
    printf 'Active target descendants:\n%s\n' "$active_holders" >&2
    fail "the kernel is still using the target disk; reboot the live USB before retrying"
fi

printf '\nALL DATA ON %s WILL BE DESTROYED.\n' "$TARGET_DISK"
read -r -p "Type ERASE to continue: " confirmation
[[ "$confirmation" == "ERASE" ]] || fail "confirmation did not match"

prompt_password "LUKS disk passphrase" LUKS_PASSWORD
prompt_password "Password for $USER_NAME" USER_PASSWORD

printf 'Partitioning %s...\n' "$TARGET_DISK"
parted --script "$TARGET_DISK" -- mklabel gpt
parted --script "$TARGET_DISK" -- mkpart ESP fat32 1MiB 1025MiB
parted --script "$TARGET_DISK" -- set 1 esp on
parted --script "$TARGET_DISK" -- mkpart primary 1025MiB 100%
partprobe "$TARGET_DISK"
udevadm settle

mapfile -t partitions < <(lsblk -lnpo NAME,TYPE "$TARGET_DISK" | awk '$2 == "part" {print $1}')
[[ ${#partitions[@]} -eq 2 ]] \
    || fail "expected two partitions but found ${#partitions[@]}"
BOOT_PARTITION=${partitions[0]}
CRYPT_PARTITION=${partitions[1]}

mkfs.fat -F 32 -n NIXBOOT "$BOOT_PARTITION"
printf '%s' "$LUKS_PASSWORD" \
    | cryptsetup luksFormat --batch-mode --type luks2 --label NIXCRYPT --key-file - "$CRYPT_PARTITION"
printf '%s' "$LUKS_PASSWORD" \
    | cryptsetup open --key-file - "$CRYPT_PARTITION" cryptroot
CRYPTROOT_OPEN=1
mkfs.btrfs -f -L NIXROOT /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
INSTALL_MOUNTS_ACTIVE=1
for subvolume in @ @home @nix @log; do
    btrfs subvolume create "/mnt/$subvolume"
done
umount /mnt
INSTALL_MOUNTS_ACTIVE=0

mount -o subvol=@,compress=zstd,noatime /dev/mapper/cryptroot /mnt
INSTALL_MOUNTS_ACTIVE=1
mkdir -p /mnt/boot /mnt/home /mnt/nix /mnt/var/log
mount -o subvol=@home,compress=zstd,noatime /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@log,compress=zstd,noatime /dev/mapper/cryptroot /mnt/var/log
mount "$BOOT_PARTITION" /mnt/boot

mkdir -p /mnt/etc/nixos
tar \
    --exclude=.git \
    --exclude='*/__pycache__' \
    --exclude='*.pyc' \
    --exclude=hardware-configuration.nix \
    --exclude=disk-config.nix \
    -C "$SCRIPT_DIR" -cf - . \
    | tar -C /mnt/etc/nixos -xf -

nixos-generate-config --root /mnt --show-hardware-config --no-filesystems \
    > /mnt/etc/nixos/hardware-configuration.nix

LUKS_UUID=$(cryptsetup luksUUID "$CRYPT_PARTITION")
BOOT_UUID=$(blkid -s UUID -o value "$BOOT_PARTITION")
[[ -n "$LUKS_UUID" && -n "$BOOT_UUID" ]] || fail "could not read filesystem UUIDs"

sed \
    -e "s|@LUKS_UUID@|$LUKS_UUID|g" \
    -e "s|@BOOT_UUID@|$BOOT_UUID|g" \
    /mnt/etc/nixos/disk-config.nix.template \
    > /mnt/etc/nixos/disk-config.nix

[[ -f /mnt/etc/nixos/flake.lock ]] \
    || fail "the pinned flake.lock was not copied to the target"

# The live ISO uses RAM-backed writable filesystems. Keep downloads, evaluation
# caches, and temporary files on the encrypted target so a large desktop closure
# cannot exhaust the live environment before nixos-install reaches its target
# store. The committed lock file is used unchanged for reproducibility.
export XDG_CACHE_HOME=/mnt/nix/.installer-cache
export TMPDIR=/mnt/nix/.installer-tmp
mkdir -p "$XDG_CACHE_HOME" "$TMPDIR"
chmod 0700 "$XDG_CACHE_HOME"
chmod 1777 "$TMPDIR"

printf 'Target capacity before installation:\n'
df -h /mnt /mnt/nix /mnt/boot
printf 'Installing NixOS from the pinned flake...\n'
nixos-install \
    --root /mnt \
    --flake /mnt/etc/nixos#laptop \
    --no-channel-copy \
    --no-write-lock-file \
    --no-root-passwd

printf '%s:%s\n' "$USER_NAME" "$USER_PASSWORD" \
    | nixos-enter --root /mnt -c 'chpasswd'

clear_secrets
rm -rf "$XDG_CACHE_HOME" "$TMPDIR"
sync
umount -R /mnt
INSTALL_MOUNTS_ACTIVE=0
cryptsetup close cryptroot
CRYPTROOT_OPEN=0

printf '\nInstallation complete. Host: %s, user: %s.\n' "$HOST_NAME" "$USER_NAME"
printf 'After the first desktop starts, run /etc/nixos/post-install.sh as %s.\n' "$USER_NAME"
if [[ $REBOOT_AFTER_INSTALL -eq 1 ]]; then
    printf 'Rebooting into the encrypted installation...\n'
    systemctl reboot
else
    printf 'Reboot manually when ready.\n'
fi

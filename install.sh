#!/usr/bin/env bash

set -Eeuo pipefail

readonly USER_NAME="victor"
readonly HOST_NAME="nixfwbtw"
readonly CONFIG_DIR="/home/$USER_NAME/dots"
readonly REPOSITORY_URL="https://github.com/V1K1NGbg/dots.git"
readonly REPOSITORY_BRANCH="nixos"
readonly TARGET_ROOT="/mnt"
readonly TARGET_CONFIG_DIR="$TARGET_ROOT$CONFIG_DIR"
readonly CRYPTROOT_NAME="cryptroot"
readonly CRYPTROOT_DEVICE="/dev/mapper/$CRYPTROOT_NAME"
readonly -a CAPACITY_PATHS=(
    / /nix /nix/.rw-store
    "$TARGET_ROOT" "$TARGET_ROOT/nix" "$TARGET_ROOT/boot"
)
TARGET_DISK=""
REBOOT_AFTER_INSTALL=1
LUKS_PASSWORD=""
USER_PASSWORD=""
WIFI_PROFILE_PATH=""
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

unmount_target() {
    umount -R "$TARGET_ROOT" || return
    INSTALL_MOUNTS_ACTIVE=0
}

close_cryptroot() {
    cryptsetup close "$CRYPTROOT_NAME" || return
    CRYPTROOT_OPEN=0
}

find_wifi_profile() {
    local uuid=$1
    local profile_directory candidate

    for profile_directory in \
        /etc/NetworkManager/system-connections \
        /run/NetworkManager/system-connections; do
        [[ -d "$profile_directory" ]] || continue
        while IFS= read -r -d '' candidate; do
            if grep -Fqx -- "uuid=$uuid" "$candidate"; then
                WIFI_PROFILE_PATH=$candidate
                return
            fi
        done < <(find "$profile_directory" -maxdepth 1 -type f -print0)
    done
}

mount_subvolume() {
    local subvolume=$1
    local target=$2

    mount -o "subvol=$subvolume,compress=zstd,noatime" "$CRYPTROOT_DEVICE" "$target"
}

on_exit() {
    local status=$?

    clear_secrets
    if [[ $status -ne 0 ]]; then
        printf '\nInstallation failed. Filesystem capacity at failure:\n' >&2
        df -h "${CAPACITY_PATHS[@]}" 2>/dev/null >&2 || true
        printf '\nInode capacity at failure:\n' >&2
        df -i "${CAPACITY_PATHS[@]}" 2>/dev/null >&2 || true

        if [[ $INSTALL_MOUNTS_ACTIVE -eq 1 ]]; then
            printf '\nUnmounting the incomplete target installation...\n' >&2
            unmount_target \
                || printf 'WARNING: %s is busy; leave %s and run: sudo umount -R %s\n' \
                    "$TARGET_ROOT" "$TARGET_ROOT" "$TARGET_ROOT" >&2
        fi
        if [[ $CRYPTROOT_OPEN -eq 1 && $INSTALL_MOUNTS_ACTIVE -eq 0 ]]; then
            close_cryptroot \
                || printf 'WARNING: run: sudo cryptsetup close %s\n' "$CRYPTROOT_NAME" >&2
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

required_commands=(
    awk basename blkid btrfs cryptsetup curl dirname find git grep install lsblk mkfs.btrfs mkfs.fat
    df mount nix nixos-enter nixos-generate-config nixos-install parted
    nmcli nmtui partprobe sed udevadm umount
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

git ls-remote --exit-code --heads \
    "$REPOSITORY_URL" "refs/heads/$REPOSITORY_BRANCH" >/dev/null \
    || fail "cannot access branch '$REPOSITORY_BRANCH' at $REPOSITORY_URL"

active_wifi_uuid=$(
    nmcli -t -f UUID,TYPE connection show --active \
        | awk -F: '$2 == "802-11-wireless" || $2 == "wifi" { print $1; exit }'
)
[[ -n "$active_wifi_uuid" ]] \
    || fail "no active Wi-Fi connection; connect with nmtui and run the installer again"

wifi_connection_name=$(nmcli -g connection.id connection show uuid "$active_wifi_uuid")
find_wifi_profile "$active_wifi_uuid"
[[ -n "$WIFI_PROFILE_PATH" && -r "$WIFI_PROFILE_PATH" ]] \
    || fail "the active Wi-Fi profile is not saved on disk; reconnect with nmtui and retry"

printf "The installed system will reuse Wi-Fi connection '%s'.\n" "$wifi_connection_name"

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

if [[ -e "$CRYPTROOT_DEVICE" ]]; then
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
    | cryptsetup open --key-file - "$CRYPT_PARTITION" "$CRYPTROOT_NAME"
CRYPTROOT_OPEN=1
mkfs.btrfs -f -L NIXROOT "$CRYPTROOT_DEVICE"

mount "$CRYPTROOT_DEVICE" "$TARGET_ROOT"
INSTALL_MOUNTS_ACTIVE=1
for subvolume in @ @home @nix @log; do
    btrfs subvolume create "$TARGET_ROOT/$subvolume"
done
unmount_target

mount_subvolume @ "$TARGET_ROOT"
INSTALL_MOUNTS_ACTIVE=1
mkdir -p "$TARGET_ROOT/boot" "$TARGET_ROOT/home" "$TARGET_ROOT/nix" "$TARGET_ROOT/var/log"
mount_subvolume @home "$TARGET_ROOT/home"
mount_subvolume @nix "$TARGET_ROOT/nix"
mount_subvolume @log "$TARGET_ROOT/var/log"
mount "$BOOT_PARTITION" "$TARGET_ROOT/boot"

printf "Cloning %s branch '%s' into %s...\n" \
    "$REPOSITORY_URL" "$REPOSITORY_BRANCH" "$CONFIG_DIR"
mkdir -p "$(dirname -- "$TARGET_CONFIG_DIR")"
git clone \
    --branch "$REPOSITORY_BRANCH" \
    --single-branch \
    "$REPOSITORY_URL" \
    "$TARGET_CONFIG_DIR"

target_wifi_profile="$TARGET_ROOT/etc/NetworkManager/system-connections/$(basename -- "$WIFI_PROFILE_PATH")"
install -D -m 0600 /dev/null "$target_wifi_profile"
nmcli --offline connection modify \
    connection.autoconnect yes \
    connection.permissions "" \
    < "$WIFI_PROFILE_PATH" \
    > "$target_wifi_profile"
chmod 0600 "$target_wifi_profile"

nixos-generate-config --root "$TARGET_ROOT" --show-hardware-config --no-filesystems \
    > "$TARGET_CONFIG_DIR/nix/hardware-configuration.nix"

LUKS_UUID=$(cryptsetup luksUUID "$CRYPT_PARTITION")
BOOT_UUID=$(blkid -s UUID -o value "$BOOT_PARTITION")
[[ -n "$LUKS_UUID" && -n "$BOOT_UUID" ]] || fail "could not read filesystem UUIDs"

sed \
    -e "s|@LUKS_UUID@|$LUKS_UUID|g" \
    -e "s|@BOOT_UUID@|$BOOT_UUID|g" \
    "$TARGET_CONFIG_DIR/nix/disk-config.nix.template" \
    > "$TARGET_CONFIG_DIR/nix/disk-config.nix"

[[ -f "$TARGET_CONFIG_DIR/flake.lock" ]] \
    || fail "the cloned branch does not contain the pinned flake.lock"

# The live ISO uses RAM-backed writable filesystems. Keep downloads, evaluation
# caches, and temporary files on the encrypted target so a large desktop closure
# cannot exhaust the live environment before nixos-install reaches its target
# store. The committed lock file is used unchanged for reproducibility.
export XDG_CACHE_HOME="$TARGET_ROOT/nix/.installer-cache"
export TMPDIR="$TARGET_ROOT/nix/.installer-tmp"
mkdir -p "$XDG_CACHE_HOME" "$TMPDIR"
chmod 0700 "$XDG_CACHE_HOME"
chmod 1777 "$TMPDIR"

printf 'Target capacity before installation:\n'
df -h "$TARGET_ROOT" "$TARGET_ROOT/nix" "$TARGET_ROOT/boot"
printf 'Installing NixOS from the pinned flake...\n'
nixos-install \
    --root "$TARGET_ROOT" \
    --flake "$TARGET_CONFIG_DIR#laptop" \
    --no-channel-copy \
    --no-write-lock-file \
    --no-root-passwd

printf '%s:%s\n' "$USER_NAME" "$USER_PASSWORD" \
    | nixos-enter --root "$TARGET_ROOT" -c 'chpasswd'
nixos-enter --root "$TARGET_ROOT" -c "chown $USER_NAME:users '/home/$USER_NAME'"
nixos-enter --root "$TARGET_ROOT" -c "chown -R $USER_NAME:users '$CONFIG_DIR'"

clear_secrets
rm -rf "$XDG_CACHE_HOME" "$TMPDIR"
sync
unmount_target
close_cryptroot

printf '\nInstallation complete. Host: %s, user: %s.\n' "$HOST_NAME" "$USER_NAME"
printf 'After the first desktop starts, run %s/post-install.sh as %s.\n' "$CONFIG_DIR" "$USER_NAME"
if [[ $REBOOT_AFTER_INSTALL -eq 1 ]]; then
    printf 'Rebooting into the encrypted installation...\n'
    systemctl reboot
else
    printf 'Reboot manually when ready.\n'
fi

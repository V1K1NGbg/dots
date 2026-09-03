#!/usr/bin/env bash

# Stage 1: run from the Arch Linux live ISO in UEFI mode.
set -Eeuo pipefail
umask 077

USER_NAME="victor"
HOST_NAME="archfwbtw"
TARGET_ROOT="/mnt"
CRYPT_NAME="cryptroot"
CRYPT_DEVICE="/dev/mapper/$CRYPT_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_DISK=""
NETWORK_CONFIG=""
NO_REBOOT=0
MOUNTED=0
CRYPT_OPEN=0
LUKS_PASSWORD=""
USER_PASSWORD=""

usage() {
    cat <<'EOF'
Usage: sudo ./bootstrap.sh [--disk /dev/DEVICE] [--network-config PATH] [--no-reboot]

The selected disk is completely erased. PATH may be one NetworkManager profile
or a directory containing profiles copied from system-connections.
EOF
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

prompt_password() {
    local prompt=$1 destination=$2 first second

    while true; do
        read -r -s -p "$prompt: " first
        printf '\n'
        read -r -s -p "Confirm $prompt: " second
        printf '\n'
        if [[ -n "$first" && "$first" == "$second" ]]; then
            printf -v "$destination" '%s' "$first"
            return
        fi
        printf 'Passwords must be non-empty and match.\n' >&2
    done
}

cleanup() {
    local status=$?

    LUKS_PASSWORD=""
    USER_PASSWORD=""
    if (( status != 0 )); then
        (( MOUNTED == 1 )) && umount -R "$TARGET_ROOT" 2>/dev/null || true
        (( CRYPT_OPEN == 1 )) && cryptsetup close "$CRYPT_NAME" 2>/dev/null || true
    fi
    return "$status"
}
trap cleanup EXIT

copy_network_config() {
    local profile
    local destination="$TARGET_ROOT/etc/NetworkManager/system-connections"

    [[ -n "$NETWORK_CONFIG" ]] || return
    [[ -e "$NETWORK_CONFIG" ]] || fail "network config not found: $NETWORK_CONFIG"
    install -d -m 0700 "$destination"

    if [[ -f "$NETWORK_CONFIG" ]]; then
        install -m 0600 "$NETWORK_CONFIG" \
            "$destination/$(basename -- "$NETWORK_CONFIG")"
    elif [[ -d "$NETWORK_CONFIG" ]]; then
        while IFS= read -r -d '' profile; do
            install -m 0600 "$profile" "$destination/$(basename -- "$profile")"
        done < <(find "$NETWORK_CONFIG" -maxdepth 1 -type f -print0)
    else
        fail "network config must be a file or directory"
    fi
}

while (( $# > 0 )); do
    case "$1" in
        --disk)
            [[ $# -ge 2 ]] || fail "--disk requires a device"
            TARGET_DISK=$2
            shift 2
            ;;
        --network-config)
            [[ $# -ge 2 ]] || fail "--network-config requires a path"
            NETWORK_CONFIG=$2
            shift 2
            ;;
        --no-reboot)
            NO_REBOOT=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "unknown option: $1"
            ;;
    esac
done

[[ $EUID -eq 0 ]] || fail "run as root"
[[ -d /sys/firmware/efi ]] || fail "boot the Arch ISO in UEFI mode"
mountpoint -q "$TARGET_ROOT" && fail "$TARGET_ROOT is already mounted"
[[ ! -e "$CRYPT_DEVICE" ]] || fail "$CRYPT_DEVICE is already open"
curl -fsSI https://archlinux.org/ >/dev/null \
    || fail "connect to the internet with iwctl and retry"

if [[ -z "$TARGET_DISK" ]]; then
    lsblk -dnpo NAME,SIZE,MODEL,TYPE | awk '$4 == "disk"'
    read -r -p "Target disk: " TARGET_DISK
fi

[[ -b "$TARGET_DISK" ]] || fail "not a block device: $TARGET_DISK"
[[ "$(lsblk -dno TYPE "$TARGET_DISK")" == "disk" ]] \
    || fail "select a whole disk, not a partition"
[[ -z "$(lsblk -nrpo MOUNTPOINTS "$TARGET_DISK" | sed '/^$/d')" ]] \
    || fail "the target disk contains mounted filesystems"

printf '\nALL DATA ON %s WILL BE ERASED.\n' "$TARGET_DISK"
read -r -p "Type 'ERASE $TARGET_DISK' to continue: " confirmation
[[ "$confirmation" == "ERASE $TARGET_DISK" ]] || fail "installation cancelled"

prompt_password "LUKS passphrase" LUKS_PASSWORD
prompt_password "Password for $USER_NAME" USER_PASSWORD

parted --script "$TARGET_DISK" -- mklabel gpt
parted --script "$TARGET_DISK" -- mkpart ESP fat32 1MiB 1025MiB
parted --script "$TARGET_DISK" -- set 1 esp on
parted --script "$TARGET_DISK" -- mkpart primary 1025MiB 100%
partprobe "$TARGET_DISK"
udevadm settle

mapfile -t partitions < <(
    lsblk -lnpo NAME,TYPE "$TARGET_DISK" | awk '$2 == "part" { print $1 }'
)
[[ ${#partitions[@]} -eq 2 ]] || fail "expected exactly two partitions"
BOOT_PARTITION=${partitions[0]}
ROOT_PARTITION=${partitions[1]}

mkfs.fat -F 32 -n ARCHBOOT "$BOOT_PARTITION"
printf '%s' "$LUKS_PASSWORD" \
    | cryptsetup luksFormat --batch-mode --type luks2 --key-file - "$ROOT_PARTITION"
printf '%s' "$LUKS_PASSWORD" \
    | cryptsetup open --key-file - "$ROOT_PARTITION" "$CRYPT_NAME"
LUKS_PASSWORD=""
CRYPT_OPEN=1

mkfs.ext4 -F -L ARCHROOT "$CRYPT_DEVICE"
mount "$CRYPT_DEVICE" "$TARGET_ROOT"
MOUNTED=1
mkdir -p "$TARGET_ROOT/boot"
mount -o umask=0077 "$BOOT_PARTITION" "$TARGET_ROOT/boot"

# Only install enough for an encrypted, graphical first boot. install.sh adds
# the complete package set and all AUR packages from inside Hyprland.
pacstrap -K "$TARGET_ROOT" \
    base linux linux-firmware amd-ucode binutils cryptsetup dracut e2fsprogs \
    git sudo networkmanager network-manager-applet \
    hyprland uwsm alacritty waybar mako rofi hypridle hyprpolkitagent hyprsunset \
    pipewire pipewire-pulse wireplumber \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    capitaine-cursors cliphist cowsay lolcat noto-fonts wl-clipboard

genfstab -U "$TARGET_ROOT" > "$TARGET_ROOT/etc/fstab"
ln -sf /usr/share/zoneinfo/Europe/Amsterdam "$TARGET_ROOT/etc/localtime"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' "$TARGET_ROOT/etc/locale.gen"
printf 'LANG=en_US.UTF-8\n' > "$TARGET_ROOT/etc/locale.conf"
printf '%s\n' "$HOST_NAME" > "$TARGET_ROOT/etc/hostname"
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' \
    "$HOST_NAME" "$HOST_NAME" > "$TARGET_ROOT/etc/hosts"

arch-chroot "$TARGET_ROOT" locale-gen
arch-chroot "$TARGET_ROOT" hwclock --systohc
arch-chroot "$TARGET_ROOT" useradd -m -U -G wheel -s /bin/bash "$USER_NAME"
printf '%s:%s\n' "$USER_NAME" "$USER_PASSWORD" \
    | arch-chroot "$TARGET_ROOT" chpasswd
USER_PASSWORD=""
arch-chroot "$TARGET_ROOT" passwd -l root
printf '%%wheel ALL=(ALL:ALL) ALL\n' > "$TARGET_ROOT/etc/sudoers.d/10-wheel"
chmod 0440 "$TARGET_ROOT/etc/sudoers.d/10-wheel"

copy_network_config
arch-chroot "$TARGET_ROOT" systemctl enable NetworkManager.service

TARGET_HOME="$TARGET_ROOT/home/$USER_NAME"
TARGET_REPO="$TARGET_HOME/dots"
mkdir -p "$TARGET_REPO" "$TARGET_HOME/.config"
cp -a "$SCRIPT_DIR/." "$TARGET_REPO/"
for config_dir in \
    alacritty gtk-3.0 gtk-4.0 hypr mako qt5ct qt6ct rofi systemd uwsm waybar; do
    cp -a "$TARGET_REPO/.config/$config_dir" "$TARGET_HOME/.config/"
done
cp -a "$TARGET_REPO/.bash_profile" "$TARGET_REPO/.bashrc" "$TARGET_HOME/"

mkdir -p "$TARGET_ROOT/etc/systemd/system/getty@tty1.service.d"
cat > "$TARGET_ROOT/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF
arch-chroot "$TARGET_ROOT" chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME"

LUKS_UUID=$(cryptsetup luksUUID "$ROOT_PARTITION")
KERNEL_CMDLINE="rd.luks.name=$LUKS_UUID=$CRYPT_NAME root=$CRYPT_DEVICE rootfstype=ext4 rw"
mkdir -p "$TARGET_ROOT/etc/dracut.conf.d" "$TARGET_ROOT/etc/kernel" \
    "$TARGET_ROOT/boot/EFI/Linux" "$TARGET_ROOT/boot/loader"
printf '%s\n' "$KERNEL_CMDLINE" > "$TARGET_ROOT/etc/kernel/cmdline"
printf 'uefi="yes"\nhostonly="yes"\nadd_dracutmodules+=" crypt "\n' \
    > "$TARGET_ROOT/etc/dracut.conf.d/10-uki.conf"
printf 'kernel_cmdline="%s"\n' "$KERNEL_CMDLINE" \
    > "$TARGET_ROOT/etc/dracut.conf.d/20-cmdline.conf"
printf 'timeout 3\nconsole-mode max\neditor no\n' \
    > "$TARGET_ROOT/boot/loader/loader.conf"

systemd-machine-id-setup --root="$TARGET_ROOT"
arch-chroot "$TARGET_ROOT" bootctl --esp-path=/boot install
arch-chroot "$TARGET_ROOT" dracut --regenerate-all --force
compgen -G "$TARGET_ROOT/boot/EFI/Linux/*.efi" >/dev/null \
    || fail "dracut did not create a unified kernel image"

sync
umount -R "$TARGET_ROOT"
MOUNTED=0
cryptsetup close "$CRYPT_NAME"
CRYPT_OPEN=0

printf '\nInstallation complete. Finish setup in Hyprland with:\n'
printf '  cd ~/dots && ./install.sh\n'
if (( NO_REBOOT == 0 )); then
    systemctl reboot
fi

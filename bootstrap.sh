#!/usr/bin/env bash

# Stage 1: run from the Arch Linux live ISO in UEFI mode.
set -Eeuo pipefail
# System directories must be traversable by service accounts. Wi-Fi credentials
# use explicit 0600 permissions and private temporary directories.
umask 022

USER_NAME="victor"
HOST_NAME="archfwbtw"
TARGET_ROOT="/mnt"
CRYPT_NAME="cryptroot"
CRYPT_DEVICE="/dev/mapper/$CRYPT_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_DISK=""
NETWORK_STAGE=""
NO_REBOOT=0
MOUNTED=0
CRYPT_OPEN=0
LUKS_PASSWORD=""
USER_PASSWORD=""

usage() {
    cat <<'EOF'
Usage: sudo ./bootstrap.sh [--disk /dev/DEVICE] [--no-reboot]

The selected disk is completely erased. Tab completes paths at the disk prompt.
By default, the Wi-Fi currently connected through iwctl is copied automatically
from iwd to NetworkManager in the installed OS. No export is needed.
Boot the standard Arch ISO with copytoram=y so the USB can be removed at the end.
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
    if [[ -n "$NETWORK_STAGE" ]]; then
        rm -rf -- "$NETWORK_STAGE"
    fi
    if (( status != 0 )); then
        (( MOUNTED == 1 )) && umount -R "$TARGET_ROOT" 2>/dev/null || true
        (( CRYPT_OPEN == 1 )) && cryptsetup close "$CRYPT_NAME" 2>/dev/null || true
    fi
    return "$status"
}

copy_network_config() {
    local profile
    local destination="$TARGET_ROOT/etc/NetworkManager/system-connections"

    [[ -n "$NETWORK_STAGE" ]] || return 0
    install -d -m 0700 "$destination"
    while IFS= read -r -d '' profile; do
        install -o root -g root -m 0600 "$profile" "$destination/$(basename -- "$profile")"
    done < <(find "$NETWORK_STAGE" -maxdepth 1 -type f -print0)
}

# Copy connected personal/open iwd networks using Arch ISO tools.
copy_iwd_networks() (
    set -euo pipefail
    umask 077
    export LC_ALL=C

    # Decode only the five escapes accepted by iwd keyfiles. Never source credentials.
    unescape() {
        local value=$1 char i
        REPLY=""
        for (( i=0; i<${#value}; i++ )); do
            char=${value:i:1}
            if [[ "$char" == \\ ]]; then
                i=$((i + 1))
                case "${value:i:1}" in
                    s) char=' ' ;; t) char=$'\t' ;; r) char=$'\r' ;;
                    n) char=$'\n' ;; \\) char='\' ;;
                    *) fail "invalid escape in iwd profile" ;;
                esac
            fi
            REPLY+=$char
        done
    }

    escape() {
        REPLY=${1//\\/\\\\}
        REPLY=${REPLY// /\\s}
        REPLY=${REPLY//$'\t'/\\t}
        REPLY=${REPLY//$'\r'/\\r}
        REPLY=${REPLY//$'\n'/\\n}
    }

    boolean() {
        case "${1,,}" in
            true|1) REPLY=true ;; false|0) REPLY=false ;;
            *) fail "invalid boolean in iwd profile" ;;
        esac
    }

    # iwd names files with the literal SSID or = followed by its hex-encoded bytes.
    profile_hex() {
        local name=${1##*/}
        name=${name%.*}
        if [[ "$name" == =* ]]; then
            REPLY=${name:1}
        else
            REPLY=$(printf '%s' "$name" | od -An -v -tx1 | tr -d ' \n')
        fi
        [[ "$REPLY" =~ ^([[:xdigit:]]{2}){1,32}$ ]] || fail "invalid SSID in iwd profile filename"
        REPLY=${REPLY,,}
    }

    render_profile() {
        local profile=$1 hex=$2 type=${1##*.}
        local line section='' key value hidden psk=''
        local digest uuid ssid='' label='' char byte i
        local -A settings=()
        [[ -f "$profile" && ! -L "$profile" ]] || fail "expected a regular saved iwd profile"
        [[ "$type" != 8021x ]] || fail "enterprise Wi-Fi is not supported"
        while IFS= read -r line || [[ -n "$line" ]]; do
            line=${line%$'\r'}
            line=${line#"${line%%[!$' \t']*}"}
            [[ -n "$line" && "$line" != \#* ]] || continue
            if [[ "$line" =~ ^\[([^][]+)\][[:blank:]]*$ ]]; then
                section=${BASH_REMATCH[1]}
            elif [[ -n "$section" && "$line" == *=* ]]; then
                key=${line%%=*}
                key=${key%"${key##*[!$' \t']}"}
                value=${line#*=}
                value=${value#"${value%%[!$' \t']*}"}
                case "$section.$key" in
                    Security.EncryptedSecurity|Security.EncryptedSalt) fail "encrypted iwd credentials are not supported" ;;
                    Security.Passphrase|Security.PreSharedKey|Settings.Hidden|Settings.AutoConnect) ;;
                    *) fail "unsupported iwd setting: $section.$key; only basic personal/open Wi-Fi is supported" ;;
                esac
                unescape "$value"
                settings["$section.$key"]=$REPLY
            else
                fail "invalid iwd profile syntax"
            fi
        done < "$profile"

        boolean "${settings[Settings.AutoConnect]:-true}"
        boolean "${settings[Settings.Hidden]:-false}"; hidden=$REPLY
        if [[ "$type" == psk ]]; then
            if [[ -n "${settings[Security.Passphrase]+present}" ]]; then
                psk=${settings[Security.Passphrase]}
                (( ${#psk} >= 8 && ${#psk} <= 63 )) || fail "invalid saved Wi-Fi passphrase length"
            else
                psk=${settings[Security.PreSharedKey]:-}
                [[ "$psk" =~ ^[[:xdigit:]]{64}$ ]] \
                    || fail "no usable saved Wi-Fi credential; reconnect with iwctl and retry"
            fi
        elif [[ -n ${settings[Security.Passphrase]+present}${settings[Security.PreSharedKey]+present} ]]; then
            fail "unexpected credentials in an open Wi-Fi profile"
        fi

        for (( i=0; i<${#hex}; i+=2 )); do
            byte=${hex:i:2}
            ssid+="$((16#$byte));"
            if [[ "$byte" != 00 ]]; then
                printf -v char '%b' "\x$byte"
                label+=$char
            fi
        done
        [[ "$label" != *[![:print:]]* && -n "$label" ]] || label="Wi-Fi $hex"
        # A stable custom UUID keeps repeated conversions of the same network consistent.
        digest=$(printf '%s' "$hex.$type" | sha256sum)
        uuid=${digest:0:8}-${digest:8:4}-8${digest:13:3}-8${digest:17:3}-${digest:20:12}
        escape "$label"
        printf '[connection]\nid=%s\nuuid=%s\ntype=wifi\nautoconnect=true\n\n' "$REPLY" "$uuid"
        printf '[wifi]\nmode=infrastructure\nssid=%s\nhidden=%s\n' "$ssid" "$hidden"
        if [[ "$type" == psk ]]; then
            escape "$psk"
            printf '\n[wifi-security]\nkey-mgmt=wpa-psk\npsk=%s\npsk-flags=0\n' "$REPLY"
        fi
        printf '\n[ipv4]\nmethod=auto\n\n[ipv6]\nmethod=auto\n'
    }

    local source destination tree path response network token profile hex stage
    local count=0
    local -A active=()
    [[ $# == 2 ]] || fail "copy_iwd_networks requires SOURCE DESTINATION"
    source=$1 destination=$2
    tree=$(busctl --system --timeout=10 --list tree net.connman.iwd) \
        || fail "could not query iwd; connect with iwctl and retry"
    while IFS= read -r path; do
        response=$(busctl --system --timeout=10 get-property net.connman.iwd "$path" \
            net.connman.iwd.Station ConnectedNetwork 2>/dev/null) || continue
        [[ "$response" =~ ^o\ \"(/[a-zA-Z0-9_/]*)\"$ ]] || fail "unexpected connected-network response from iwd"
        network=${BASH_REMATCH[1]}
        [[ "$network" != / ]] || continue
        # iwd's network object basename is the SSID bytes in hex plus _TYPE.
        # https://kernel.googlesource.com/pub/scm/network/wireless/iwd/+/master/src/station.c
        token=${network##*/}
        [[ "$token" =~ ^([[:xdigit:]]{2}){1,32}_(psk|open|8021x)$ ]] || fail "unsupported iwd network path"
        active["${token,,}"]=1
    done <<< "$tree"

    mkdir -p -- "$destination"
    chmod 0700 "$destination"
    stage=$(mktemp -d "$destination/.iwd.XXXXXX")
    trap 'rm -rf -- "$stage"' EXIT
    shopt -s nullglob
    for profile in "$source"/*.psk "$source"/*.open "$source"/*.8021x; do
        profile_hex "$profile"; hex=$REPLY
        token=${hex}_${profile##*.}
        [[ -n "${active[$token]:-}" ]] || continue
        render_profile "$profile" "$hex" > "$stage/iwd-$hex.${profile##*.}.nmconnection"
        unset 'active[$token]'
        count=$((count + 1))
    done
    (( ${#active[@]} == 0 )) || fail "the connected Wi-Fi has no saved iwd profile; reconnect with iwctl and retry"
    # Publish only after all selected credentials have been validated.
    for profile in "$stage"/*.nmconnection; do
        mv -f -- "$profile" "$destination/${profile##*/}"
    done
    printf 'Prepared %d saved iwd Wi-Fi profile(s) for NetworkManager.\n' "$count"
)

prepare_network_config() {
    NETWORK_STAGE=$(mktemp -d /tmp/dots-network.XXXXXX)
    copy_iwd_networks /var/lib/iwd "$NETWORK_STAGE"
}

validate_live_media() {
    local device backing
    # Check the actual backing store, not just the requested kernel option.
    [[ $(findmnt -nro FSTYPE /) == overlay &&
       ,$(findmnt -nro OPTIONS /), == *,lowerdir=/run/archiso/airootfs,* &&
       $(findmnt -nro FSTYPE -M /run/archiso/copytoram) == tmpfs &&
       $(findmnt -nro FSTYPE -M /run/archiso/cowspace) == tmpfs ]] \
        || fail 'Boot the standard Arch ISO with copytoram=y (no persistent overlay).'
    device=$(findmnt -nro SOURCE -M /run/archiso/airootfs) || fail 'Cannot locate the live root image.'
    backing=$(losetup -nro BACK-FILE "$device") || fail 'Cannot inspect the live root image.'
    case "$backing" in
        /run/archiso/copytoram/airootfs.sfs|/run/archiso/copytoram/airootfs.erofs) ;;
        *) fail 'The live root image is not backed by RAM; reboot with copytoram=y.' ;;
    esac
    # Loop-boot/persistent layouts need their own removal procedure.
    if mountpoint -q /run/archiso/img_dev; then
        fail 'Use a directly written Arch ISO USB, not a loop-mounted ISO.'
    fi
}

finish_installation() {
    sync
    umount -R "$TARGET_ROOT" || fail 'Could not unmount the installed system.'
    MOUNTED=0
    cryptsetup close "$CRYPT_NAME" || fail 'Could not close the installed encrypted volume.'
    CRYPT_OPEN=0
    validate_live_media
    cd /
    if mountpoint -q /run/archiso/bootmnt; then
        umount /run/archiso/bootmnt || fail 'USB is still busy; do not remove it.'
    fi
    printf '\nInstallation complete. Finish setup in Hyprland with:\n'
    printf '  cd ~/dots && ./install.sh\n'
    if (( NO_REBOOT == 0 )); then
        read -r -p 'Remove the USB stick and press Enter to reboot: ' || return 1
        systemctl reboot
    else
        printf 'The installation USB can now be removed. Reboot when ready.\n'
    fi
}

validate_target_disk() {
    local disk=$1 mounts
    [[ -b "$disk" ]] || fail "not a block device: $disk"
    [[ "$(lsblk -dno TYPE "$disk")" == "disk" ]] \
        || fail "select a whole disk, not a partition"
    mounts=$(lsblk -nrpo MOUNTPOINTS "$disk" | sed '/^$/d') \
        || fail "could not inspect mounted filesystems on $disk"
    [[ -z "$mounts" ]] \
        || fail "the target disk contains mounted filesystems"
}

# Allow the read-only preflight to be checked without entering the installer.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then return 0; fi
trap cleanup EXIT

while (( $# > 0 )); do
    case "$1" in
        --disk)
            [[ $# -ge 2 ]] || fail "--disk requires a device"
            TARGET_DISK=$2
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
validate_live_media
mountpoint -q "$TARGET_ROOT" && fail "$TARGET_ROOT is already mounted"
[[ ! -e "$CRYPT_DEVICE" ]] || fail "$CRYPT_DEVICE is already open"
curl -fsSI https://archlinux.org/ >/dev/null \
    || fail "connect to the internet with iwctl and retry"

if [[ -z "$TARGET_DISK" ]]; then
    lsblk -dnpo TYPE,NAME,SIZE,MODEL | awk '$1 == "disk" { $1=""; sub(/^ /, ""); print }'
    # Readline supplies filename completion, including /dev/disk/by-id aliases.
    read -e -r -i /dev/ -p "Target disk (Tab to complete): " TARGET_DISK
fi

validate_target_disk "$TARGET_DISK"

# Catch missing/unsupported credentials before any destructive operation.
prepare_network_config

printf '\nALL DATA ON %s WILL BE ERASED.\n' "$TARGET_DISK"
read -r -p "Type 'ERASE' to continue: " confirmation
[[ "$confirmation" == "ERASE" ]] || fail "installation cancelled"

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
BOOT_PARTITION=""
ROOT_PARTITION=""
for partition in "${partitions[@]}"; do
    # lsblk may list p2 before p1; use the kernel's partition number.
    partition_number=$(cat "/sys/class/block/${partition##*/}/partition")
    case "$partition_number" in
        1) BOOT_PARTITION=$partition ;;
        2) ROOT_PARTITION=$partition ;;
        *) fail "unexpected partition number: $partition_number" ;;
    esac
done
[[ -n "$BOOT_PARTITION" && -n "$ROOT_PARTITION" ]] \
    || fail "could not identify boot partition 1 and root partition 2"
printf 'Boot partition: %s\nRoot partition: %s\n' "$BOOT_PARTITION" "$ROOT_PARTITION"

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
# Enable multilib before pacstrap synchronizes the fresh system's databases.
sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
pacstrap -K "$TARGET_ROOT" \
    base linux linux-firmware amd-ucode binutils cryptsetup dracut e2fsprogs \
    git vim sudo networkmanager network-manager-applet \
    hyprland uwsm alacritty waybar mako rofi hypridle hyprlock hyprpolkitagent hyprsunset \
    pipewire pipewire-pulse wireplumber libpulse playerctl jq fd fzf curl libnotify \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    capitaine-cursors cliphist cowsay lolcat noto-fonts wl-clipboard

sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' "$TARGET_ROOT/etc/pacman.conf"

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
arch-chroot "$TARGET_ROOT" bash "/home/$USER_NAME/dots/install.sh" --install-lockscreen
for config_dir in \
    alacritty gtk-3.0 gtk-4.0 hypr mako miku qt5ct qt6ct rofi systemd uwsm visualizer waybar; do
    cp -a "$TARGET_REPO/config/.config/$config_dir" "$TARGET_HOME/.config/"
done
cp -a "$TARGET_REPO/config/.bash_profile" "$TARGET_REPO/config/.bashrc" "$TARGET_HOME/"
mkdir -p "$TARGET_HOME/.local/share"
cp -a "$TARGET_REPO/assets/sounds" "$TARGET_HOME/.local/share/dots-sounds"

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
chmod 0755 "$TARGET_ROOT/etc/kernel"
chmod 0644 "$TARGET_ROOT/etc/kernel/cmdline"
printf 'uefi="yes"\nhostonly="yes"\nadd_dracutmodules+=" crypt "\n' \
    > "$TARGET_ROOT/etc/dracut.conf.d/10-uki.conf"
printf 'kernel_cmdline="%s"\n' "$KERNEL_CMDLINE" \
    > "$TARGET_ROOT/etc/dracut.conf.d/20-cmdline.conf"
printf 'timeout 3\nconsole-mode max\neditor no\n' \
    > "$TARGET_ROOT/boot/loader/loader.conf"

arch-chroot "$TARGET_ROOT" bash "/home/$USER_NAME/dots/install.sh" --setup-power

systemd-machine-id-setup --root="$TARGET_ROOT"
arch-chroot "$TARGET_ROOT" bootctl --esp-path=/boot install
install -Dm0644 "$SCRIPT_DIR/config/system/pacman-hooks/90-dracut-install.hook" \
    "$TARGET_ROOT/etc/pacman.d/hooks/90-dracut-install.hook"
arch-chroot "$TARGET_ROOT" dracut --regenerate-all --force
compgen -G "$TARGET_ROOT/boot/EFI/Linux/*.efi" >/dev/null \
    || fail "dracut did not create a unified kernel image"

finish_installation

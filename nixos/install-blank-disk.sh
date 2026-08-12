#!/usr/bin/env bash

set -euo pipefail

disk_argument="${1:-}"
configuration="${2:-dots}"
reboot_after="${3:-}"
target="/mnt"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
Usage: install-blank-disk.sh /dev/WHOLE_DISK [dots|dots-hyprland] [--reboot]

This erases the complete disk and creates:
  partition 1: 1 GiB FAT32 EFI System Partition
  partition 2: remaining space, ext4 NixOS root

Example:
  ./nixos/install-blank-disk.sh /dev/nvme0n1 dots --reboot
EOF
  exit 2
}

[[ -n ${disk_argument} ]] || usage
[[ ${EUID} -eq 0 ]] || die "Run this script as root."
[[ -d /sys/firmware/efi ]] || die "The live ISO was not booted in UEFI mode."

case "${configuration}" in
  dots | dots-hyprland) ;;
  *) die "Unknown configuration '${configuration}'." ;;
esac

case "${reboot_after}" in
  "" | --reboot) ;;
  *) usage ;;
esac

for command in \
  blockdev findmnt grep lsblk mkdir mkfs.ext4 mkfs.fat mount partprobe parted \
  realpath sleep sync udevadm umount wipefs; do
  command -v "${command}" >/dev/null 2>&1 || die "Required command is unavailable: ${command}"
done
if [[ ${reboot_after} == --reboot ]]; then
  command -v reboot >/dev/null 2>&1 || die "Required command is unavailable: reboot"
fi

disk="$(realpath -- "${disk_argument}")"
[[ ${disk} == /dev/* ]] || die "The target must resolve to a device under /dev."
[[ -b ${disk} ]] || die "Not a block device: ${disk}"
[[ $(lsblk -dnro TYPE "${disk}") == disk ]] || die "Pass a whole disk, not a partition: ${disk}"
[[ $(lsblk -dnro RM "${disk}") == 0 ]] || die "Refusing to erase a removable disk: ${disk}"
[[ $(lsblk -dnro TRAN "${disk}") != usb ]] || die "Refusing to erase a USB disk: ${disk}"

if lsblk -nrpo MOUNTPOINT "${disk}" | grep -q '[^[:space:]]'; then
  echo "Mounted filesystems detected on ${disk}:" >&2
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "${disk}" >&2
  die "Refusing to erase a disk with mounted filesystems."
fi

if findmnt --mountpoint "${target}" >/dev/null 2>&1; then
  die "${target} is already mounted; unmount it before using the blank-disk installer."
fi

disk_bytes="$(blockdev --getsize64 "${disk}")"
((disk_bytes >= 34359738368)) || die "Refusing to install to a disk smaller than 32 GiB."

echo "The following whole disk will be permanently erased:"
lsblk -dn -o PATH,SIZE,MODEL,SERIAL,TRAN,RM "${disk}"
echo
echo "Planned layout:"
echo "  ${disk}: GPT"
echo "  partition 1: 1 GiB FAT32 EFI System Partition, label NIXBOOT"
echo "  partition 2: remaining space ext4 root, label nixos"
echo "  configuration: ${configuration}"
echo
echo "ALL PARTITIONS AND DATA ON ${disk} WILL BE DESTROYED."
read -r -p "Type 'ERASE ${disk}' to continue: " confirmation
[[ ${confirmation} == "ERASE ${disk}" ]] || die "Confirmation did not match; nothing was erased."

echo "Erasing old signatures and creating the GPT partition table..."
wipefs --all --force "${disk}"
parted --script --align optimal "${disk}" \
  mklabel gpt \
  mkpart ESP fat32 1MiB 1025MiB \
  set 1 esp on \
  mkpart primary ext4 1025MiB 100%
partprobe "${disk}"
udevadm settle

if [[ ${disk} =~ [0-9]$ ]]; then
  efi_partition="${disk}p1"
  root_partition="${disk}p2"
else
  efi_partition="${disk}1"
  root_partition="${disk}2"
fi

for _ in {1..10}; do
  [[ -b ${efi_partition} && -b ${root_partition} ]] && break
  udevadm settle
  sleep 1
done
[[ -b ${efi_partition} ]] || die "EFI partition did not appear: ${efi_partition}"
[[ -b ${root_partition} ]] || die "Root partition did not appear: ${root_partition}"

echo "Formatting ${efi_partition} as FAT32 and ${root_partition} as ext4..."
mkfs.fat -F 32 -n NIXBOOT "${efi_partition}"
mkfs.ext4 -F -L nixos "${root_partition}"

echo "Mounting the new system at ${target}..."
mount "${root_partition}" "${target}"
mkdir -p "${target}/boot"
mount -o umask=077 "${efi_partition}" "${target}/boot"

echo "Mounted installation target:"
findmnt "${target}"
findmnt "${target}/boot"

# The exact disk-erasure confirmation above also authorizes the inner installer.
DOTS_INSTALL_CONFIRMED="${target}:${configuration}" \
DOTS_NO_ROOT_PASSWORD=1 \
  "${script_dir}/install-from-minimal.sh" "${target}" "${configuration}"

echo "Flushing writes and unmounting the installed system..."
sync
umount -R "${target}"

echo
echo "Installation and unmount completed successfully."
if [[ ${reboot_after} == --reboot ]]; then
  read -r -p "Remove the installer USB, then type REBOOT: " reboot_confirmation
  [[ ${reboot_confirmation} == REBOOT ]] || die "Reboot cancelled; installation is complete and unmounted."
  reboot
else
  echo "Remove the installer USB and run: reboot"
fi

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

cleanup_mounts() {
  if findmnt --mountpoint "${target}" >/dev/null 2>&1; then
    sync
    umount -R "${target}" || echo "WARNING: could not fully unmount ${target}; inspect it before rebooting." >&2
  fi
}

usage() {
  cat >&2 <<'EOF'
Usage: install-blank-disk.sh /dev/WHOLE_DISK [dots] [--reboot]

This uses the repository's declarative Disko layout to erase the complete disk
and create:
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
  dots) ;;
  *) die "Unknown configuration '${configuration}'." ;;
esac

case "${reboot_after}" in
  "" | --reboot) ;;
  *) usage ;;
esac

for command in blockdev findmnt grep lsblk nix realpath sync umount; do
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

repo="$(realpath "${script_dir}/..")"
flake="path:${repo}"
[[ -f ${repo}/flake.lock ]] || die "flake.lock is missing; refusing to use unpinned Disko inputs."

configured_disk="$(
  nix --extra-experimental-features "nix-command flakes" \
    eval --raw --no-write-lock-file \
    "${flake}#nixosConfigurations.${configuration}.config.disko.devices.disk.system.device"
)"
configured_disk="$(realpath -- "${configured_disk}")"
if [[ ${disk} != "${configured_disk}" ]]; then
  die "${configuration} declares ${configured_disk}, not ${disk}. Change nixos/disko.nix deliberately before installing."
fi

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

echo "Applying the locked declarative Disko layout..."
nix --extra-experimental-features "nix-command flakes" \
  run --no-write-lock-file "${flake}#disko" -- \
  --mode destroy,format,mount \
  --root-mountpoint "${target}" \
  --yes-wipe-all-disks \
  --flake "${flake}#${configuration}"

echo "Mounted installation target:"
findmnt --mountpoint "${target}" || die "Disko did not mount the root filesystem at ${target}."
findmnt --mountpoint "${target}/boot" || die "Disko did not mount the EFI filesystem at ${target}/boot."
trap cleanup_mounts EXIT

# The exact disk-erasure confirmation above also authorizes the inner installer.
DOTS_INSTALL_CONFIRMED="${target}:${configuration}" \
DOTS_NO_ROOT_PASSWORD=1 \
  "${script_dir}/install-from-minimal.sh" "${target}" "${configuration}"

echo "Flushing writes and unmounting the Disko-managed filesystems..."
sync
umount -R "${target}"
trap - EXIT

echo
echo "Installation and unmount completed successfully."
if [[ ${reboot_after} == --reboot ]]; then
  read -r -p "Remove the installer USB, then type REBOOT: " reboot_confirmation
  [[ ${reboot_confirmation} == REBOOT ]] || die "Reboot cancelled; installation is complete and unmounted."
  reboot
else
  echo "Remove the installer USB and run: reboot"
fi

#!/usr/bin/env bash

set -euo pipefail

target="${1:-/mnt}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(realpath "${script_dir}/..")"
flake="path:${repo}"
hardware_source="${target}/etc/nixos/hardware-configuration.nix"
hardware_target="${script_dir}/hardware-configuration.nix"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root (normally: sudo $0 ${target})." >&2
  exit 1
fi

for command in findmnt nix nixos-generate-config nixos-install nixos-enter realpath; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command is unavailable on this installer: ${command}" >&2
    exit 1
  fi
done

if ! findmnt --mountpoint "${target}" >/dev/null 2>&1; then
  echo "The target root is not mounted at ${target}." >&2
  exit 1
fi

if [[ ! -d /sys/firmware/efi ]]; then
  echo "This configuration uses systemd-boot, but the installer was not booted in UEFI mode." >&2
  exit 1
fi

if ! findmnt --mountpoint "${target}/boot" >/dev/null 2>&1; then
  echo "Mount the EFI system partition at ${target}/boot before continuing." >&2
  exit 1
fi

echo "Generating hardware configuration for ${target}..."
nixos-generate-config --root "${target}"

if [[ -e "${hardware_target}" ]] && ! cmp -s "${hardware_source}" "${hardware_target}"; then
  backup="${hardware_target}.pre-install-backup"
  cp --preserve=mode,timestamps "${hardware_target}" "${backup}"
  echo "Existing hardware configuration backed up to ${backup}."
fi
install -m 0644 "${hardware_source}" "${hardware_target}"

echo "Locking and evaluating the flake..."
nix --extra-experimental-features "nix-command flakes" flake lock "${flake}"
nix --extra-experimental-features "nix-command flakes" flake check --no-build "${flake}"

echo "Installing NixOS. nixos-install will ask for the root password."
nixos-install \
  --root "${target}" \
  --option experimental-features "nix-command flakes" \
  --flake "${flake}#dots"

echo "Set the password for the victor account."
nixos-enter --root "${target}" -c "passwd victor"

echo "Installation complete. Reboot after unmounting ${target}."

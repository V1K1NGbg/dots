#!/usr/bin/env bash

set -euo pipefail

target="${1:-/mnt}"
configuration="${2:-dots}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(realpath "${script_dir}/..")"
target="$(realpath "${target}")"
flake="path:${repo}"
hardware_source="${target}/etc/nixos/hardware-configuration.nix"
hardware_target="${script_dir}/hardware-configuration.nix"
checkout_target="${target}/home/victor/dots"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

if [[ ${EUID} -ne 0 ]]; then
  die "Run this script as root (normally: sudo $0 ${target} ${configuration})."
fi

[[ ${target} != / ]] || die "Refusing to install into the live root filesystem."

case "${configuration}" in
  dots | dots-hyprland)
    ;;
  *)
    die "Unknown configuration '${configuration}'. See nixos/README.md for valid names."
    ;;
esac

for command in cmp cp findmnt install nix nixos-enter nixos-generate-config nixos-install realpath; do
  command -v "${command}" >/dev/null 2>&1 || die "Required installer command is unavailable: ${command}"
done

[[ -f ${repo}/flake.lock ]] || die "flake.lock is missing; do not install from unpinned inputs."
findmnt --mountpoint "${target}" >/dev/null 2>&1 || die "The target root is not mounted at ${target}."
[[ -d /sys/firmware/efi ]] || die "The installer was not booted in UEFI mode."
findmnt --mountpoint "${target}/boot" >/dev/null 2>&1 || \
  die "Mount the EFI system partition at ${target}/boot before continuing."

root_source="$(findmnt --noheadings --output SOURCE --target "${target}")"
boot_source="$(findmnt --noheadings --output SOURCE --target "${target}/boot")"

case "${repo}/" in
  "${target}/"*) ;;
  *) [[ ! -e ${checkout_target} ]] || die "Refusing to overwrite existing ${checkout_target}." ;;
esac

echo "Target root:       ${target} (${root_source})"
echo "Target EFI:        ${target}/boot (${boot_source})"
echo "Configuration:     ${configuration}"
echo "Source checkout:   ${repo}"
echo
echo "This helper does not partition or format disks. It will generate hardware"
echo "configuration, build the selected system, and install it into the mounts above."
if [[ ${DOTS_INSTALL_CONFIRMED:-} != "${target}:${configuration}" ]]; then
  read -r -p "Type INSTALL to continue: " confirmation
  [[ ${confirmation} == INSTALL ]] || die "Installation cancelled."
fi

echo "Generating target-specific hardware configuration..."
nixos-generate-config --no-filesystems --root "${target}"

if [[ -e ${hardware_target} ]] && ! cmp -s "${hardware_source}" "${hardware_target}"; then
  backup="${hardware_target}.pre-install-backup"
  cp --preserve=mode,timestamps "${hardware_target}" "${backup}"
  echo "Previous hardware configuration backed up to ${backup}."
fi
install -m 0644 "${hardware_source}" "${hardware_target}"

echo "Running the locked repository safety checks..."
nix --extra-experimental-features "nix-command flakes" \
  build --no-link --no-update-lock-file \
  "${flake}#checks.x86_64-linux.static-syntax"

echo "Building ${configuration} before changing the installed system..."
nix --extra-experimental-features "nix-command flakes" \
  build --no-link --no-update-lock-file \
  "${flake}#nixosConfigurations.${configuration}.config.system.build.toplevel"

echo "Installing NixOS..."
nixos_install_arguments=(
  --root "${target}"
  --option experimental-features "nix-command flakes"
  --flake "${flake}#${configuration}"
)
if [[ ${DOTS_NO_ROOT_PASSWORD:-0} == 1 ]]; then
  nixos_install_arguments+=(--no-root-passwd)
else
  echo "nixos-install will ask for the root password."
fi
nixos-install "${nixos_install_arguments[@]}"

case "${repo}/" in
  "${target}/"*)
    relative_repo="/${repo#"${target}/"}"
    echo "The checkout is already on the target filesystem at ${relative_repo}."
    nixos-enter --root "${target}" -c "chown -R victor:users '${relative_repo}'"
    ;;
  *)
    install -d -m 0755 "$(dirname "${checkout_target}")"
    cp -a "${repo}" "${checkout_target}"
    nixos-enter --root "${target}" -c "chown -R victor:users /home/victor/dots"
    echo "Preserved this exact checkout at /home/victor/dots on the installed system."
    ;;
esac

echo "Set the password for the victor account."
nixos-enter --root "${target}" -c "passwd victor"

echo
echo "Installation complete. Reboot only after unmounting ${target}."
echo "After login, run: cd ~/dots && nix run .#onboard"

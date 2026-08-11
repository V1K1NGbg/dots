{ cryptsetup, disko-install, git, nixos-install-tools, pkgs, repoRoot, util-linux }:
pkgs.writeShellApplication {
  name = "install-nixfwbtw";
  runtimeInputs = [
    cryptsetup
    disko-install
    git
    nixos-install-tools
    pkgs.coreutils
    pkgs.gnugrep
    util-linux
  ];

  text = ''
    usage() {
      printf 'usage: sudo nix run .#install -- [--dry-run] /dev/disk/by-id/DEVICE\n'
    }

    dry_run=false
    if [[ ''${1:-} == --dry-run ]]; then
      dry_run=true
      shift
    fi
    [[ $# == 1 ]] || { usage >&2; exit 2; }

    requested_disk=$1
    [[ $requested_disk == /dev/disk/by-id/* ]] || {
      printf 'error: use a stable /dev/disk/by-id path, not %s\n' "$requested_disk" >&2
      exit 2
    }
    [[ -L $requested_disk ]] || {
      printf 'error: %s is not a device symlink\n' "$requested_disk" >&2
      exit 2
    }
    disk=$(realpath -e -- "$requested_disk")
    [[ -b $disk && $(lsblk -dnro TYPE "$disk") == disk ]] || {
      printf 'error: %s does not resolve to a whole block device\n' "$requested_disk" >&2
      exit 2
    }

    if lsblk -nrpo MOUNTPOINT "$disk" | grep -qv '^$'; then
      printf 'error: the target or one of its partitions is mounted:\n' >&2
      lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$disk" >&2
      exit 1
    fi
    if mountpoint -q /mnt || findmnt -rn -R /mnt | grep -q .; then
      printf 'error: /mnt is already in use; unmount it before installation\n' >&2
      exit 1
    fi
    if cryptsetup status cryptroot >/dev/null 2>&1; then
      printf 'error: /dev/mapper/cryptroot already exists; refusing to reuse it\n' >&2
      exit 1
    fi
    for label in disk-main-root disk-main-ESP; do
      label_path="/dev/disk/by-partlabel/$label"
      if [[ -e $label_path ]]; then
        existing_partition=$(realpath -e "$label_path")
        existing_parent="/dev/$(lsblk -ndo PKNAME "$existing_partition")"
        [[ $existing_parent == "$disk" ]] || {
          printf 'error: partition label %s already belongs to another disk\n' "$label" >&2
          exit 1
        }
      fi
    done

    printf '\nTarget selected for complete erasure:\n'
    lsblk -o NAME,MODEL,SERIAL,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$disk"
    printf '\nLayout: GPT, 1 GiB EFI, LUKS2-encrypted ext4 root, zram swap.\n'

    install_args=(
      --flake ${repoRoot}#nixfwbtw
      --disk main "$requested_disk"
      --mode format
      --mount-point /mnt
      --write-efi-boot-entries
      --show-trace
    )

    if $dry_run; then
      exec disko-install --dry-run "''${install_args[@]}"
    fi
    [[ $EUID == 0 ]] || {
      printf 'error: run the installer through sudo as shown in the usage text\n' >&2
      exit 1
    }

    expected="ERASE $requested_disk"
    read -r -p "Type '$expected' to continue: " confirmation
    [[ $confirmation == "$expected" ]] || {
      printf 'Cancelled; no disk changes were made.\n'
      exit 1
    }

    key_file=/tmp/nixfwbtw-luks.key
    [[ ! -e $key_file ]] || {
      printf 'error: refusing to overwrite existing %s\n' "$key_file" >&2
      exit 1
    }

    cleanup() {
      if mountpoint -q /mnt; then
        umount -R /mnt || true
      fi
      if cryptsetup status cryptroot >/dev/null 2>&1; then
        cryptsetup close cryptroot || true
      fi
      rm -f -- "$key_file"
    }
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    read -r -s -p 'New disk-encryption passphrase: ' passphrase
    printf '\n'
    read -r -s -p 'Repeat disk-encryption passphrase: ' repeated
    printf '\n'
    [[ -n $passphrase && $passphrase == "$repeated" ]] || {
      printf 'error: passphrases were empty or did not match\n' >&2
      exit 1
    }
    umask 077
    printf '%s' "$passphrase" >"$key_file"
    unset passphrase repeated

    # disko-install builds the complete NixOS system before it erases anything.
    # Only a successful build proceeds to partition, format, mount, and install.
    disko-install "''${install_args[@]}"

    mkdir -p /mnt
    root_partition=$(realpath -e /dev/disk/by-partlabel/disk-main-root)
    efi_partition=$(realpath -e /dev/disk/by-partlabel/disk-main-ESP)
    [[ /dev/$(lsblk -ndo PKNAME "$root_partition") == "$disk" ]] || {
      printf 'error: root partition label does not belong to the selected disk\n' >&2
      exit 1
    }
    [[ /dev/$(lsblk -ndo PKNAME "$efi_partition") == "$disk" ]] || {
      printf 'error: EFI partition label does not belong to the selected disk\n' >&2
      exit 1
    }
    if ! cryptsetup status cryptroot >/dev/null 2>&1; then
      cryptsetup open "$root_partition" cryptroot --key-file "$key_file"
    fi
    mount /dev/mapper/cryptroot /mnt
    mkdir -p /mnt/boot
    mount "$efi_partition" /mnt/boot

    mkdir -p /mnt/home/victor/dots
    cp -R --no-preserve=ownership "${repoRoot}/." /mnt/home/victor/dots/
    chmod -R u+w /mnt/home/victor/dots
    if [[ -d $PWD/.git ]] && git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1; then
      cp -R "$PWD/.git" /mnt/home/victor/dots/.git
    fi
    nixos-enter --root /mnt -c 'chown -R victor:users /home/victor/dots'

    printf '\nSet Victor’s login and sudo password now.\n'
    nixos-enter --root /mnt -c 'passwd victor'

    printf '\nInstallation complete. The disk will now be unmounted safely.\n'
    printf 'Reboot, remove the installer USB, and unlock cryptroot at boot.\n'
  '';
}

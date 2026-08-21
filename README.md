# Automated encrypted NixOS laptop install

This repository installs an encrypted, Hyprland-based NixOS desktop from the
minimal NixOS live USB. The target is a UEFI x86-64 laptop with an AMD GPU.

## Install

Commit and push the desired configuration to the `nixos` branch first. Boot the
USB in UEFI mode, connect it to the Wi-Fi network the installed system should
reuse, obtain `install.sh` from that branch, and run:

```bash
sudo ./install.sh --disk /dev/nvme0n1
```

Omit `--disk` to choose from a short physical-disk list. Add `--no-reboot` when
testing. The installer asks only for:

1. The target disk, if it was not passed on the command line.
2. A destructive-action confirmation containing that exact disk path.
3. The LUKS passphrase, twice.
4. The `victor` password, twice.

Everything on the selected disk is erased. Before doing so, the installer
verifies the remote `nixos` branch and captures the active NetworkManager Wi-Fi
profile. The script creates a 1 GiB EFI partition and a LUKS2-encrypted Btrfs
partition with separate `@`, `@home`, `@nix`, and `@log` subvolumes, clones that
branch into `~/dots`, installs the Wi-Fi profile with root-only permissions,
generates hardware configuration, and installs the system using the cloned
`flake.lock`. It then sets the user password without putting it in the Nix
store, unmounts the disk, and reboots. Nix evaluation caches and temporary
downloads are placed on the encrypted target during installation instead of
the live USB's RAM-backed writable filesystem. The generated hardware and disk
modules replace their tracked generic versions, so the installed checkout will
show those machine-specific modifications in `git status`.

### Live USB reports no space left

Use the latest `install.sh` and restart the installation. An older version
re-ran `nix flake lock` in the live environment, which could exhaust its small
writable overlay while evaluating a large desktop configuration. The current
installer uses the committed lock file unchanged and places `TMPDIR` and
`XDG_CACHE_HOME` under `/mnt/nix`.

If an installation still fails, the script automatically prints block and inode
usage for the live root, live Nix overlay, encrypted target, Nix subvolume, and
EFI partition, then unmounts the incomplete target and closes `cryptroot` when
possible. Preserve that final diagnostic output; it identifies which filesystem
actually filled up.

If `parted` says it wrote the partition table but could not inform the kernel,
the old target is still mounted or has an open device-mapper holder. Reboot the
live USB, make sure the target is not opened by a file manager, and retry with
the latest script. The installer now refuses to repartition a disk with an
active `cryptroot`, mounted descendant, swap partition, or mapped descendant and
prints the relevant `lsblk` device tree instead.

## Login and security flow

At boot, Plymouth shows the `hexagon_hud` theme while the initrd asks for the
LUKS passphrase. After decryption, SDDM automatically starts the UWSM-managed
Hyprland session as `victor`; there is no second login prompt. Hyprlock and
`sudo` accept the separate `victor` password or an enrolled fingerprint. If
Hyprland exits, the custom Monocraft SDDM greeter is shown instead of repeating
automatic login. That greeter also accepts the password or fingerprint (press
Enter, then scan a finger).

This matches the requested trust model: possession of the disk passphrase is
enough to reach the desktop, while later unlocks and privilege elevation need
the user password. Membership in the `docker` group is intentionally enabled
and is effectively root-equivalent.

## Configuration

The installed source is a Git checkout of the `nixos` branch in `~/dots`.
Rebuild it with:

```bash
sudo nixos-rebuild switch --flake ~/dots#laptop
```

The system includes:

- Native Wayland Hyprland input, locking, idle, clipboard, screenshots, display
  profiles, notifications, app launcher, and power-menu integration.
- `us,bg` keyboard layouts with Bulgarian `bas_phonetic`, switched with
  Super+Space; the physical power button opens the Rofi power mode. Super+D
  opens Rofi with all application and utility modes available from its mode
  switcher, and Super+B toggles Waybar.
- A minimal top bar containing only the date/time, tray icons, and battery
  percentage.
- PipeWire audio, NetworkManager with static `1.1.1.1` DNS, Bluetooth, Steam,
  and Docker enabled for `victor`.
- `amdgpu.dcdebugmask=0x40010` (PSR and the broken custom brightness curve are
  disabled), `quiet`, and `splash` kernel parameters.
- Monocraft Nerd Font 4.0 and the Alacritty palette applied to Hyprland,
  Hyprlock, SDDM, Waybar, Mako, Rofi, GTK, Qt, Vim, and tmux.
- Declarative Oh My Bash, Git identity, dotfiles, and Nemo settings.
- VS Code, Firefox, Alacritty, Discord, and Spotify launched once whenever the
  Hyprland desktop session starts. VS Code, Firefox, Alacritty, Nemo, Discord,
  Spotify, and KeePassXC are assigned to workspaces 1 through 7 respectively.

`PACKAGES` is the human decision ledger for every original package. It records
current NixOS availability, renamed attributes, Wayland replacements, and
alternatives. `packages.nix` holds the selected working set.

## Post-install setup

After the first reboot and after applying the current configuration, run this
inside Hyprland as `victor`:

```bash
cd ~/dots
./post-install.sh
```

The script validates and imports an absolute WireGuard configuration path,
runs `gh auth login`, enrolls and verifies the right index fingerprint, checks
that SDDM/login and sudo PAM include fprintd, and opens pCloud for its required
account sign-in. The standard libfprint driver is enabled declaratively. If the
reader reports `NoSuchDevice`, the script prints detected USB devices because
that laptop needs a model-specific `services.fprintd.tod.driver` selection.

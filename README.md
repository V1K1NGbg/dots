# Automated encrypted NixOS laptop install

This repository installs an encrypted, Hyprland-based NixOS desktop from the
minimal NixOS live USB. The target is a UEFI x86-64 laptop with an AMD GPU.

## Install

Boot the USB in UEFI mode, connect it to the internet, place this directory on
the live system, and run:

```bash
sudo ./install.sh --disk /dev/nvme0n1
```

Omit `--disk` to choose from a short physical-disk list. Add `--no-reboot` when
testing. The installer asks only for:

1. The target disk, if it was not passed on the command line.
2. A destructive-action confirmation containing that exact disk path.
3. The LUKS passphrase, twice.
4. The `victor` password, twice.

Everything on the selected disk is erased. The script creates a 1 GiB EFI
partition and a LUKS2-encrypted Btrfs partition with separate `@`, `@home`,
`@nix`, and `@log` subvolumes. It generates hardware configuration, locks all
flake inputs to the repository's existing `flake.lock`, installs the system,
sets the user password without putting it in the Nix store, unmounts the disk,
and reboots. Nix evaluation caches and temporary downloads are placed on the
encrypted target during installation instead of the live USB's RAM-backed
writable filesystem.

### Live USB reports no space left

Use the latest `install.sh` and restart the installation. An older version
re-ran `nix flake lock` in the live environment, which could exhaust its small
writable overlay while evaluating a large desktop configuration. The current
installer uses the committed lock file unchanged and places `TMPDIR` and
`XDG_CACHE_HOME` under `/mnt/nix`.

If an installation still fails, the script automatically prints block and inode
usage for the live root, live Nix overlay, encrypted target, Nix subvolume, and
EFI partition. Preserve that final diagnostic output; it identifies which
filesystem actually filled up.

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

The installed source is `/etc/nixos`. Rebuild it with:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#laptop
```

The system includes:

- Native Wayland Hyprland input, locking, idle, clipboard, screenshots, display
  profiles, notifications, app launcher, and power-menu integration.
- `us,bg` keyboard layouts with Bulgarian `bas_phonetic`, switched with
  Super+Space; the physical power button opens the Rofi power mode.
- PipeWire audio, NetworkManager with static `1.1.1.1` DNS, Bluetooth, Steam,
  and Docker enabled for `victor`.
- `amdgpu.dcdebugmask=0x10`, `quiet`, and `splash` kernel parameters.
- Monocraft Nerd Font 4.0 and the Alacritty palette applied to Hyprland,
  Hyprlock, SDDM, Waybar, Mako, Rofi, GTK, Qt, VS Code, Vim, and tmux.
- Declarative Oh My Bash, Git identity, dotfiles, and Nemo settings.
- VS Code, Firefox, Alacritty, Discord, and Spotify launched once whenever the
  Hyprland desktop session starts.

`PACKAGES` is the human decision ledger for every original package. It records
current NixOS availability, renamed attributes, Wayland replacements, and
alternatives. `packages.nix` holds the selected working set.

## Post-install setup

After the first reboot and after applying the current configuration, run this
inside Hyprland as `victor`:

```bash
cd /etc/nixos
./post-install.sh
```

The script validates and imports an absolute WireGuard configuration path,
runs `gh auth login`, enrolls and verifies the right index fingerprint, checks
that SDDM/login and sudo PAM include fprintd, and opens pCloud for its required
account sign-in. The standard libfprint driver is enabled declaratively. If the
reader reports `NoSuchDevice`, the script prints detected USB devices because
that laptop needs a model-specific `services.fprintd.tod.driver` selection.

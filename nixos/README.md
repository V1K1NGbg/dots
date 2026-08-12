# Conservative NixOS migration

This branch is designed to make the operating-system migration independently
from the desktop migration. The default `dots` configuration keeps the working
AwesomeWM/X11 workflow, the existing key bindings, applications, Picom
animations, monitor profiles, tray applets, startup behavior, and dotfiles.
Hyprland is available only in separately named profiles.

The inputs are immutable NixOS 26.05, Home Manager 26.05, nixos-hardware, and
Plymouth theme revisions. Their content hashes are committed in `flake.lock`.
Required daily-driver packages fail evaluation if they disappear; optional
gaps produce a visible warning and are documented in
[COMPATIBILITY.md](./COMPATIBILITY.md).

## Profiles

| Profile | Hardware module | Login/desktop |
| --- | --- | --- |
| `dots` | Framework 16, Ryzen AI 300 plus generated storage hardware | tty1 autologin, Awesome/X11 |
| `dots-hyprland` | Framework 16, Ryzen AI 300 plus generated storage hardware | chooser: Awesome or Hyprland |

There are no generic, Framework 13, or Ryzen 7040 profiles. This branch now
targets only the Framework 16 Ryzen AI 300 from the existing migration attempt.

## Validate before installing

Run these on a NixOS machine or the official minimal installer:

```sh
nix flake check --no-build
nix build .#checks.x86_64-linux.awesome-system
nix build .#checks.x86_64-linux.hyprland-system
nix build .#checks.x86_64-linux.native-ollama-system
nix build .#checks.x86_64-linux.fusuma-sendkey-config
```

The first command evaluates every published hardware/desktop combination. The
next three build complete synthetic system closures for both desktop paths and
the optional native Ollama backend. The final check parses the restored Fusuma
`sendkey:` configuration and confirms that Fusuma loads `SendkeyExecutor` from
the bundled plugin. The repository intentionally evaluates with a temporary
tmpfs root when
`hardware-configuration.nix` is absent; this placeholder is not an installable
machine configuration. The installer refuses to continue until it has replaced
it with output from `nixos-generate-config`.

An optional VM smoke test can be built on an x86_64 NixOS host:

```sh
nixos-rebuild build-vm --flake .#dots
./result/bin/run-dots-vm
```

## Install from the minimal live ISO

First commit and push the complete `nixos` branch, including all new files.
Download the current NixOS 26.05 x86_64 minimal ISO from
<https://nixos.org/download/>, write it to a USB drive, and boot the entry marked
UEFI. Keep the working Arch installation and personal-data backup until the
acceptance tests in [MIGRATION.md](./MIGRATION.md) pass.

At the live console, become root, confirm UEFI, and connect to the network:

```sh
sudo -i
test -d /sys/firmware/efi/efivars && echo "UEFI boot confirmed"
nmtui
ping -c 3 nixos.org
lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL,MOUNTPOINTS
```

Clone the pushed branch:

```sh
nix-shell -p git --run 'git clone --branch nixos https://github.com/V1K1NGbg/dots.git /tmp/dots'
cd /tmp/dots
```

### Automatic blank-disk installation

For a **blank dedicated disk only**, verify the disk path and then run one
command. Replace `/dev/nvme0n1` only after checking its model and size in
`lsblk`. The `--reboot` form waits for you to remove the USB before rebooting:

```sh
./nixos/install-blank-disk.sh /dev/nvme0n1 dots --reboot
```

The script accepts only a whole disk, refuses disks with mounted filesystems,
refuses disks smaller than 32 GiB, displays the disk model/size/serial, and
requires typing `ERASE /dev/...` exactly. It then creates GPT, a 1 GiB FAT32 EFI
partition, and an ext4 root partition using the remaining space. It formats and
mounts them, generates the real hardware configuration, runs the locked checks,
builds before installing, preserves the exact checkout at `~/dots`, asks only
for the `victor` password, syncs, and unmounts everything. With `--reboot`, it
requires you to remove the USB and type `REBOOT` before restarting.

This permanently destroys all data on the selected disk. It does not provide
encryption, dual boot, a separate home partition, hibernation swap, or in-place
migration. For any of those, partition and mount manually, then use the safer
mount-only helper:

```sh
./nixos/install-from-minimal.sh /mnt dots
```

Without `--reboot`, the automatic helper stops after a successful unmount:

```sh
reboot
```

## First boot and normal updates

Start with Awesome, run the checklist, and resolve every item that matters to
the daily workflow:

```sh
cd ~/dots
nix run .#onboard
systemctl --failed
systemctl --user --failed
```

Use `boot` for initial changes so a bad new generation is never activated in
the current session:

```sh
sudo nixos-rebuild boot --flake .#dots
```

After the configuration has proved stable across reboots, `switch` is
reasonable. The boot menu retains previous generations, and `master` remains
untouched as the source of the known-good Arch setup.

Machine policy lives in `machine.nix`. In particular, Ollama defaults to the
compatible Docker backend, bound to localhost. After migrating its models,
change `dots.ollama.backend` to `"native"` for the pinned NixOS Vulkan service.

## State ownership

Home Manager normally implements `xdg.configFile` using symlinks into the
read-only Nix store. Linking an entire application directory can therefore
prevent the application from saving settings, or make a later activation put
the repository's old settings back. This branch now separates static config
from application-owned state:

- BetterDiscord plugin JavaScript and themes remain repository-controlled and
  read-only. Plugin JSON settings are copied once and remain writable.
- KeePassXC and Flameshot preferences are copied only when their destination is
  absent. Changes made in their GUIs survive later rebuilds.
- GTK `settings.ini` remains declarative; GTK bookmarks are a writable one-time
  seed.
- Nemo and CopyQ exports are placed under `~/.local/share/dots/imports`. Nothing
  imports them automatically, so you decide once whether to apply them.
- Vimium, Bonjourr, and marketplace exports are also retained as manual imports.
- The private Awesome weather module is writable at
  `~/.local/state/dots/awesome-const.lua` and is not committed.
- Browser profiles, credentials, keys, databases, pCloud content, Docker
  volumes, and application logins remain ordinary mutable state and require a
  backup/migration.

See [MIGRATION.md](./MIGRATION.md) for the staged decision process and
[COMPATIBILITY.md](./COMPATIBILITY.md) for tool-by-tool status.

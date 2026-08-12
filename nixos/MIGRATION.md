# Migration runbook and decision gates

The safe path is two migrations, not one: first Arch to NixOS while retaining
Awesome/X11, then an optional Awesome-to-Hyprland trial. A successful first
stage does not obligate a desktop switch.

## 1. Preserve rollback paths

Before installation:

- Push or otherwise back up `master` and this `nixos` branch.
- Back up the complete home directory, browser profiles, KeePass databases,
  SSH/GPG/WireGuard keys, Docker volumes, pCloud data that is not fully synced,
  and any untracked files.
- Export a package list from the running Arch machine and keep `install.sh`.
- Prefer a spare disk. If reusing the current disk, keep tested external rescue
  media and a restorable backup.
- Record `lsblk -f`, `findmnt`, `lscpu`, `lspci -nnk`, and the Framework chassis
  size before wiping anything.

Do not treat a Git repository as a personal-data backup.

## 2. Prove evaluation and builds

On an x86_64 NixOS environment:

```sh
nix flake check --no-build
nix build .#checks.x86_64-linux.awesome-system
nix build .#checks.x86_64-linux.hyprland-system
nix build .#checks.x86_64-linux.native-ollama-system
nix build .#checks.x86_64-linux.fusuma-sendkey-config
```

Do not install if an input would be fetched outside `flake.lock`, a required
package assertion fails, or the complete Awesome closure does not build.

## 3. Install only the Awesome profile

Install `dots` first. It is the Framework 16 Ryzen AI 300 Awesome profile. The
installer generates storage-specific configuration and builds before it calls
`nixos-install`.

Keep `dots.hardware.amdgpuDisplayFix = true` for initial parity with the working
system. Test with it disabled later only if the display issue is known to be
fixed for the installed kernel and hardware.

## 4. Acceptance tests on Awesome/X11

Use the machine normally for at least several days and verify:

| Area | Pass condition |
| --- | --- |
| Boot/rollback | New system boots repeatedly; an older generation boots from the menu |
| Displays | Laptop/external displays, refresh rates, suspend/resume, hotplug and autorandr profiles work |
| Input | US/BG switching, repeat rate, touchpad, Fusuma gestures and fingerprint unlock work |
| Desktop | Awesome key bindings, tags, Picom animations, lock, tray and startup applications work |
| Audio/video | PipeWire, microphone, Bluetooth audio, VLC, screen capture and Steam work |
| Applications | Firefox, VS Code, Nemo, KeePassXC, Discord, Spotify, pCloud, CopyQ and OpenCode work with real data |
| Development | Git/GitHub auth, languages, formatters, LSPs, Docker and AppImages work |
| AI | Ollama serves locally, uses the intended GPU path, and models survive reboot |
| Recovery | You can rebuild from `~/dots` and boot the prior generation after a deliberately bad test change |

If a must-have item fails, fix it on the Awesome profile or return to Arch. Do
not introduce Hyprland while the operating-system migration is still being
debugged.

## 5. Trial Hyprland without replacing Awesome

Build first:

```sh
nix build .#checks.x86_64-linux.hyprland-system
sudo nixos-rebuild boot --flake .#dots-hyprland
```

After reboot, the chooser offers both Awesome and Hyprland. XWayland remains
enabled. Waybar supplies workspaces, window title, tray, network, audio, load,
memory, battery, and clock. The
Hyprland profile uses native workspace/touchpad bindings, Grim/Slurp/Satty for
screenshots, and Hyprsunset instead of relying on X11-only utilities.

Evaluate the Hyprland session for at least a week against the same acceptance
table. Pay special attention to Discord/BetterDiscord, pCloud, CopyQ clipboard
history, GLava, screen sharing, Steam games, global shortcuts, display hotplug,
fingerprint locking, and tray behavior. An app merely opening through XWayland
is not enough; its complete workflow must work.

## 6. Roll back or decide

To make Awesome the next boot again:

```sh
sudo nixos-rebuild boot --flake .#dots
```

If a rebuild itself is broken, select the prior NixOS generation in
systemd-boot. If NixOS is unsuitable, restore or boot the preserved Arch system;
`master` was not modified by this branch.

Keep both sessions if each has useful strengths. Retire Awesome only when every
must-have workflow has a tested Hyprland replacement and the XWayland-dependent
list is acceptably small. NixOS and Hyprland are independent decisions.

## Updating pinned inputs later

Do not switch URLs back to floating branch names. Update one input revision at
a time, regenerate `flake.lock`, run both full system builds, and boot the new
generation before updating another input. Commit the URL and lock-file change
together so rollback remains meaningful.

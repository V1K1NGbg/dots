# NixOS and Hyprland acceptance plan

The `dots` configuration targets the Framework Laptop 16 Ryzen AI 300 running
Hyprland. Keep a personal-data backup and a known-good NixOS boot generation
until the checks below pass.

## Before activation

```sh
nix flake check --no-build
nix build .#checks.x86_64-linux.hyprland-system
nix build .#checks.x86_64-linux.fusuma-sendkey-config
```

Activate changes for the next boot first:

```sh
sudo nixos-rebuild boot --flake .#dots
sudo reboot
```

## Acceptance checks

- Displays select their preferred mode and automatic placement; hotplug and
  suspend/resume work.
- The US keyboard layout and touchpad natural scrolling work.
- `Super+R` opens Rofi and `Super+Enter` opens Alacritty after login and resume.
- The solid wallpaper, tiling, borders, and animations appear as configured.
- Firefox, VS Code, Nemo, Discord, Spotify, KeePassXC, CopyQ, pCloud, Steam,
  screen sharing, file pickers, and clipboard access work.
- Audio controls, Bluetooth, fingerprint authentication, Docker, and Fusuma
  work without failed system or user services; `llama-cli` launches and detects
  the Vulkan backend.

Inspect failures with:

```sh
systemctl --failed
systemctl --user --failed
journalctl --user -b -u pcloud
```

If a new generation is unusable, select an older NixOS generation from the
systemd-boot menu. Do not erase or reinstall the disk to roll back a desktop
configuration change.

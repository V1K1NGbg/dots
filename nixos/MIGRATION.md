# NixOS and Hyprland acceptance plan

The `dots` configuration targets the Framework Laptop 16 Ryzen AI 300 running
Hyprland. Keep a personal-data backup and a known-good NixOS boot generation
until the checks below pass.

## Before activation

```sh
nix flake check --no-build
nix build .#checks.x86_64-linux.hyprland-system
nix build .#checks.x86_64-linux.native-ollama-system
nix build .#checks.x86_64-linux.fusuma-sendkey-config
```

Activate changes for the next boot first:

```sh
sudo nixos-rebuild boot --flake .#dots
sudo reboot
```

## Acceptance checks

- The internal panel and known external display use the intended resolution,
  refresh rate, scale, and placement; hotplug and suspend/resume work.
- The Bulgarian layout toggles with Super+Space and key repeat feels correct.
- Touchpad tapping, natural scrolling, clickfinger, and workspace gestures work.
- Waybar, notifications, locking, idle handling, and the application launcher
  work after both login and resume.
- Firefox, VS Code, Nemo, Discord, Spotify, KeePassXC, CopyQ, pCloud, Steam,
  screen sharing, file pickers, and clipboard access work.
- Audio controls, Bluetooth, fingerprint authentication, Docker, Ollama, and
  Fusuma work without failed system or user services.

Inspect failures with:

```sh
systemctl --failed
systemctl --user --failed
journalctl --user -b -u waybar -u hypridle -u hyprpolkitagent
```

If a new generation is unusable, select an older NixOS generation from the
systemd-boot menu. Do not erase or reinstall the disk to roll back a desktop
configuration change.

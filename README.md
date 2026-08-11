# nixfwbtw

NixOS configuration with Hyprland

## Install

> This erases the selected disk.

```bash
./scripts/lock-sources
nix --extra-experimental-features 'nix-command flakes' flake check
sudo nix --extra-experimental-features 'nix-command flakes' run .#install -- /dev/disk/by-id/EXACT_DEVICE
```

## Update

```bash
nix flake check
sudo nixos-rebuild switch --flake .#nixfwbtw
```

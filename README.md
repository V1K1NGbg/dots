# Dots

## Install with:
```bash
sudo ./install.sh --disk /dev/nvme0n1
```

## Post-install with:

```bash
cd ~/dots
./post-install.sh
```

## Rebuild it with:

```bash
sudo nixos-rebuild switch --flake ~/dots#laptop
```
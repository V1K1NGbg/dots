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

The boot menu stays hidden during a normal boot. Hold Space before the firmware
hands off to systemd-boot, or open it reliably for the next reboot with:

```bash
reboot-to-boot-menu
```

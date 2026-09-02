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

## Update flake with:

```bash
nix flake update --flake ~/dots
sudo nixos-rebuild switch --flake ~/dots#laptop
```

The rebuild enables parallel fingerprint authentication in Hyprlock and PAM
fingerprint authentication for sudo. Enroll and verify one once with:

```bash
fingerprint-setup
```

Enrollments are persistent machine state in `/var/lib/fprint`; rebuilding or
switching NixOS generations does not recreate that directory.

The boot menu stays hidden during a normal boot. Hold Space before the firmware
hands off to systemd-boot, or open it reliably for the next reboot with:

```bash
reboot-to-boot-menu
```

# dots

Declarative NixOS and Home Manager configuration for Victor's Framework 16.
The active desktop is Hyprland under UWSM, with packages and system behavior
pinned by `flake.lock`.

## Start here

- [NixOS overview](nixos/README.md)
- [Post-install setup](nixos/POST_INSTALL.md)
- [Migration and acceptance checks](nixos/MIGRATION.md)
- [Compatibility decisions](nixos/COMPATIBILITY.md)

Apply changes to the next boot generation first:

```sh
sudo nixos-rebuild boot --flake .#dots
```

The old Arch/paru installer and obsolete Docker launcher were removed. Export
files and `backup.sh` remain for deliberate application-state migration; they
are not imported automatically.

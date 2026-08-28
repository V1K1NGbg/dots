{ lib, ... }:

# The installer replaces these stable labels with the exact UUIDs on the
# target system. Keeping this module makes the repository independently
# evaluable and also documents the disk layout.
import ./disk-layout.nix {
  inherit lib;
  luksDevice = "/dev/disk/by-label/NIXCRYPT";
  bootDevice = "/dev/disk/by-label/NIXBOOT";
}

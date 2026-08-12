{ lib, ... }:

{
  # Full-system checks run in a container and must never attempt efivar writes.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
}

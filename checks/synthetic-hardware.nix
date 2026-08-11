{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/minimal.nix") ];

  boot.loader.grub.enable = false;
  # Evaluation-only hardware stand-in. Disko supplies the filesystems.
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

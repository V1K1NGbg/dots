{ inputs, self, ... }:
{
  imports = [
    ./disk.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/hardware.nix
    ../../modules/nixos/hyprland.nix
    ../../modules/nixos/ollama.nix
    ../../modules/nixos/packages.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      repoRoot = self;
      inherit inputs;
    };
    users.victor = import ../../modules/home/victor;
  };
}

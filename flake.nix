{
  description = "nixfwbtw: Framework Laptop 16 NixOS and Home Manager configuration";

  inputs = {
    # Every input is an immutable revision. Run ./scripts/lock-sources once on a
    # Nix machine to record the corresponding content hashes in flake.lock.
    nixpkgs.url = "github:NixOS/nixpkgs/279b4a8275f032c566576b3f181fa0f27197f588";

    home-manager = {
      url = "github:nix-community/home-manager/c30c7955cec30d664a9baced6bc0112e263d4647";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/6ed13b1d888d5cb07dbb0723eb1df86bbacd0b9c";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/ff8702b4de27f72b4c78573dfb89ec74e36abdf1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plymouth-themes-src = {
      url = "github:adi1090x/plymouth-themes/5d8817458d764bff4ff9daae94cf1bbaabf16ede";
      flake = false;
    };

    monocraft-src = {
      url = "file+https://github.com/IdreesInc/Monocraft/releases/download/v4.0/Monocraft-nerd-fonts-patched.ttc";
      flake = false;
    };

    oh-my-bash-src = {
      url = "github:ohmybash/oh-my-bash/7d26139293dea898a98cf4adacc19af4b0955145";
      flake = false;
    };

    lobster = {
      url = "github:justchokingaround/lobster/ad9688fd1f759abaf3ffa741e77ea9d54bfe38b7";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nixos-hardware, disko, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      overlay = final: _prev: import ./packages {
        pkgs = final;
        inherit inputs;
      };
      mkSystem = hardwareModule: extraModules: lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs self; };
        modules = [
          hardwareModule
          nixos-hardware.nixosModules.framework-16-amd-ai-300-series
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          ({ ... }: { nixpkgs.overlays = [ overlay ]; })
          ./hosts/nixfwbtw
        ] ++ extraModules;
      };
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ overlay ];
      };
      onboard = pkgs.callPackage ./packages/onboard.nix { inherit pkgs; };
      installer = pkgs.callPackage ./packages/installer.nix {
        inherit (disko.packages.${system}) disko-install;
        repoRoot = self;
      };
      host = mkSystem ./hosts/nixfwbtw/hardware.nix [ ];
      synthetic = mkSystem ./checks/synthetic-hardware.nix [ ];
    in {
      nixosConfigurations.nixfwbtw = host;

      apps.${system} = {
        onboard = {
          type = "app";
          program = "${onboard}/bin/onboard";
          meta.description = "Run the post-install onboarding checklist";
        };
        install = {
          type = "app";
          program = "${installer}/bin/install-nixfwbtw";
          meta.description = "Install nixfwbtw onto a target disk";
        };
      };

      packages.${system} = {
        inherit onboard installer;
        inherit (pkgs)
          monocraft-nerd-font
          hexagon-hud-plymouth
          rofi-wayland-only
          nixfwbtw-hypr-keybinds
          nixfwbtw-hypr-screenshot
          nixfwbtw-rofi-autocorrect
          nixfwbtw-rofi-bluetooth
          nixfwbtw-rofi-media
          nixfwbtw-rofi-power
          nixfwbtw-rofi-wifi
          ;
      };

      checks.${system} = {
        hyprland-system = host.config.system.build.toplevel;
        hyprland-only = pkgs.callPackage ./checks/hyprland-only.nix {
          systemConfig = synthetic.config;
        };
        static-syntax = pkgs.runCommand "nixfwbtw-static-syntax" {
          nativeBuildInputs = with pkgs; [ bash findutils lua5_4 ripgrep ];
          src = self;
        } ''
          cp -R "$src" source
          chmod -R u+w source
          cd source
          ./scripts/check-static
          touch "$out"
        '';
        inherit onboard installer;
        inherit (pkgs)
          monocraft-nerd-font
          hexagon-hud-plymouth
          rofi-wayland-only
          nixfwbtw-hypr-keybinds
          nixfwbtw-hypr-screenshot
          nixfwbtw-rofi-autocorrect
          nixfwbtw-rofi-bluetooth
          nixfwbtw-rofi-media
          nixfwbtw-rofi-power
          nixfwbtw-rofi-wifi
          ;
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}

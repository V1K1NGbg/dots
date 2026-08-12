{
  description = "Conservative NixOS migration for V1K1NGbg/dots";

  inputs = {
    # NixOS 26.05 and its matching Home Manager release, pinned to immutable
    # revisions. flake.lock records the corresponding content hashes.
    nixpkgs.url = "github:NixOS/nixpkgs/70cc4559b10a6062b05ff1af17e0add065ccaed9";

    home-manager = {
      url = "github:nix-community/home-manager/d4fd24667c8cbef124bb70a20380cab75ec8474d";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/3e7edd9afe17e45521300e041c65de3015f4a302";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plymouth-themes-src = {
      url = "github:adi1090x/plymouth-themes/5d8817458d764bff4ff9daae94cf1bbaabf16ede";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      ...
    }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      mkSystem =
        {
          hardwareModules ? [ ],
          extraModules ? [ ],
        }:
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs self; };
          modules =
            hardwareModules
            ++ [
              ./nixos/configuration.nix
              ./nixos/modules/desktop-hyprland.nix
              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "hm-backup";
                  users.victor = import ./nixos/home.nix;
                };
              }
            ]
            ++ extraModules;
        };

      enableHyprland = {
        dots.desktop.hyprland.enable = true;
      };

      syntheticHardware = ./nixos/checks/synthetic-hardware.nix;
      awesomeCheckSystem = mkSystem {
        hardwareModules = [ syntheticHardware ];
      };
      hyprlandCheckSystem = mkSystem {
        hardwareModules = [ syntheticHardware ];
        extraModules = [ enableHyprland ];
      };
      nativeOllamaCheckSystem = mkSystem {
        hardwareModules = [ syntheticHardware ];
        extraModules = [
          {
            dots.ollama.backend = lib.mkForce "native";
          }
        ];
      };

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      onboard = pkgs.callPackage ./nixos/pkgs/onboard.nix { };
      hexagonHudPlymouth = pkgs.callPackage ./nixos/pkgs/plymouth-theme.nix {
        src = inputs.plymouth-themes-src;
      };
      fusumaSendkeyCheck =
        pkgs.runCommand "dots-fusuma-sendkey-config"
          {
            nativeBuildInputs = [
              pkgs.fusuma
              pkgs.gnugrep
            ];
          }
          ''
            fusuma --show-config -c ${./.config/fusuma/config.yml} > "$out" 2>&1
            grep -q 'sendkey:' "$out"
            grep -q 'Fusuma::Plugin::Executors::SendkeyExecutor' "$out"
          '';
    in
    {
      # Both published profiles target the Framework 16 Ryzen AI 300. `dots`
      # deliberately remains the low-risk Awesome/X11 configuration.
      nixosConfigurations = {
        dots = mkSystem {
          hardwareModules = [ nixos-hardware.nixosModules.framework-16-amd-ai-300-series ];
        };
        dots-hyprland = mkSystem {
          hardwareModules = [ nixos-hardware.nixosModules.framework-16-amd-ai-300-series ];
          extraModules = [ enableHyprland ];
        };
      };

      apps.${system}.onboard = {
        type = "app";
        program = "${onboard}/bin/dots-onboard";
        meta.description = "Run the post-install migration checklist";
      };

      packages.${system} = {
        inherit onboard;
        hexagon-hud-plymouth = hexagonHudPlymouth;
      };

      checks.${system} = {
        awesome-system = awesomeCheckSystem.config.system.build.toplevel;
        hyprland-system = hyprlandCheckSystem.config.system.build.toplevel;
        native-ollama-system = nativeOllamaCheckSystem.config.system.build.toplevel;
        fusuma-sendkey-config = fusumaSendkeyCheck;
        inherit onboard;
        hexagon-hud-plymouth = hexagonHudPlymouth;

        static-syntax =
          pkgs.runCommand "dots-static-syntax"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                findutils
                jq
                lua5_4
                ripgrep
                shellcheck
              ];
              src = self;
            }
            ''
              cp -R "$src" source
              chmod -R u+w source
              cd source
              bash ./scripts/check-nixos-static
              touch "$out"
            '';
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}

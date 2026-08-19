{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  packageSet = import ./packages.nix { inherit lib pkgs; };
  cfg = config.dots;
  llamaCpp = pkgs.llama-cpp.override { vulkanSupport = true; };
  hexagonHudPlymouth = pkgs.callPackage ./pkgs/plymouth-theme.nix {
    src = inputs.plymouth-themes-src;
  };
in
{
  imports = [
    ./modules/migration-options.nix
    ./machine.nix
  ]
  ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  assertions = [
    {
      assertion = packageSet.missingRequired == [ ];
      message = ''
        Required daily-driver packages disappeared from the pinned nixpkgs:
        ${lib.concatStringsSep ", " packageSet.missingRequired}
        Update nixos/packages.nix deliberately instead of silently dropping them.
      '';
    }
  ];

  warnings =
    lib.optional (!builtins.pathExists ./hardware-configuration.nix) ''
      nixos/hardware-configuration.nix is missing. This is expected for evaluation,
      but the installer must generate it before installation.
    ''
    ++ lib.optional (packageSet.missingOptional != [ ]) ''
      Optional package mappings unavailable in the pinned nixpkgs: ${lib.concatStringsSep ", " packageSet.missingOptional}.
      See nixos/COMPATIBILITY.md for the intentional alternatives.
    '';

  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  networking = {
    hostName = "dots";
    networkmanager.enable = true;
    # Preserve the explicitly selected resolvers from the working Arch setup.
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    firewall.enable = true;
  };

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  boot = {
    initrd = {
      kernelModules = [ "amdgpu" ];
      systemd.enable = true;
    };
    kernelParams = [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "udev.log_level=3"
    ]
    ++ lib.optional cfg.hardware.amdgpuDisplayFix "amdgpu.dcdebugmask=0x10";
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };
    plymouth = {
      enable = true;
      theme = "hexagon_hud";
      themePackages = [ hexagonHudPlymouth ];
    };
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    enableAllFirmware = true;
  };

  services = {
    blueman.enable = true;
    flatpak.enable = true;
    fprintd.enable = true;
    logind.settings.Login.HandlePowerKey = "ignore";

    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
  };

  security = {
    rtkit.enable = true;
    polkit.enable = true;
    pam.services = {
      sudo.fprintAuth = true;
    };
  };

  users.users.victor = {
    isNormalUser = true;
    description = "Victor";
    shell = pkgs.bashInteractive;
    extraGroups = [
      "audio"
      "docker"
      "input"
      "networkmanager"
      "video"
      "wheel"
    ];
  };

  programs = {
    appimage = {
      enable = true;
      binfmt = true;
    };
    bash.completion.enable = true;
    dconf.enable = true;
    firefox = {
      enable = true;
      preferencesStatus = "default";
      preferences = {
        "font.default.x-western" = "sans-serif";
        "font.name.monospace.x-western" = "Monocraft Nerd Font";
        "font.name.sans-serif.x-western" = "Monocraft Nerd Font";
        "font.name.serif.x-western" = "Monocraft Nerd Font";
      };
    };
    nix-ld.enable = true;
    steam.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  virtualisation.docker.enable = true;

  environment = {
    systemPackages = packageSet.all ++ lib.optional cfg.llamaCpp.enable llamaCpp;
  };

  fonts = {
    fontDir.enable = true;
    fontconfig.enable = true;
    fontconfig.defaultFonts = {
      emoji = [ "Noto Color Emoji" ];
      monospace = [
        "Monocraft Nerd Font"
        "Noto Color Emoji"
      ];
      sansSerif = [
        "Monocraft Nerd Font"
        "Noto Color Emoji"
      ];
      serif = [
        "Monocraft Nerd Font"
        "Noto Color Emoji"
      ];
    };
    packages = map (name: packageSet.byName.${name}) [
      "Monocraft Nerd Font"
      "noto-fonts"
      "noto-fonts-cjk"
      "noto-fonts-emoji"
      "noto-fonts-extra"
    ];
  };

  system.stateVersion = "26.05";
}

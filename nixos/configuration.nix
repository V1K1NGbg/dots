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
    ''
    ++ lib.optional (cfg.ollama.enable && cfg.ollama.backend == "docker") ''
      Ollama uses the compatible Docker backend and its mutable image tag. Select
      dots.ollama.backend = "native" after migrating the model data for a fully pinned service.
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
    initrd.kernelModules = [ "amdgpu" ];
    kernelParams = [
      "quiet"
      "splash"
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

    ollama = lib.mkIf (cfg.ollama.enable && cfg.ollama.backend == "native") {
      enable = true;
      package = pkgs.ollama-vulkan;
      host = cfg.ollama.listenAddress;
      environmentVariables = {
        OLLAMA_NUM_PARALLEL = "2";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_KEEP_ALIVE = "0";
        OLLAMA_MAX_QUEUE = "2";
        OLLAMA_VULKAN = "1";
        GPU_DEVICE_ORDINAL = "0";
        GGML_VK_VISIBLE_DEVICES = "0";
        ROC_ENABLE_PRE_VEGA = "1";
        HIP_VISIBLE_DEVICES = "0";
        OMP_NUM_THREADS = "12";
        GOMP_CPU_AFFINITY = "0-11";
        OLLAMA_FLASH_ATTENTION = "1";
        GGML_USE_MLOCK = "0";
      };
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
    nix-ld.enable = true;
    steam.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  virtualisation = {
    docker.enable = true;
    oci-containers = lib.mkIf (cfg.ollama.enable && cfg.ollama.backend == "docker") {
      backend = "docker";
      containers.ollama = {
        image = "ollama/ollama:latest";
        autoStart = true;
        ports = [ "${cfg.ollama.listenAddress}:11434:11434" ];
        volumes = [ "ollama:/root/.ollama" ];
        environment = {
          OLLAMA_NUM_PARALLEL = "2";
          OLLAMA_MAX_LOADED_MODELS = "1";
          OLLAMA_HOST = "0.0.0.0";
          OLLAMA_KEEP_ALIVE = "0";
          OLLAMA_MAX_QUEUE = "2";
          OLLAMA_VULKAN = "1";
          GPU_DEVICE_ORDINAL = "0";
          GGML_VK_VISIBLE_DEVICES = "0";
          ROC_ENABLE_PRE_VEGA = "1";
          HIP_VISIBLE_DEVICES = "0";
          OMP_NUM_THREADS = "12";
          GOMP_CPU_AFFINITY = "0-11";
          OLLAMA_FLASH_ATTENTION = "1";
          GGML_USE_MLOCK = "0";
        };
        extraOptions = [
          "--device=/dev/dri:/dev/dri"
          "--device=/dev/kfd:/dev/kfd"
          "--memory=48g"
          "--cpus=24"
          "--ulimit=memlock=-1:-1"
          "--ulimit=stack=67108864:67108864"
        ];
      };
    };
  };

  environment = {
    systemPackages = packageSet.all;
  };

  fonts = {
    fontconfig.enable = true;
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

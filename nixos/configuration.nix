{ config, lib, pkgs, ... }:

let
  packageSet = import ./packages.nix { inherit lib pkgs; };
in
{
  imports = lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
  };

  warnings =
    lib.optional (!builtins.pathExists ./hardware-configuration.nix)
      "nixos/hardware-configuration.nix is missing; copy the generated file for this machine before installing."
    ++ lib.optional (packageSet.missing != [ ])
      "No nixpkgs equivalent was found for: ${lib.concatStringsSep ", " packageSet.missing}"
    ++ lib.optional (!lib.hasAttrByPath [ "picom-pijulius" ] pkgs)
      "picom-pijulius is unavailable; upstream picom is used but may reject the checked-in animation rules.";

  networking = {
    hostName = "dots";
    networkmanager.enable = true;
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
  };

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  boot = {
    initrd.kernelModules = [ "amdgpu" ];
    kernelParams = [ "amdgpu.dcdebugmask=0x10" "quiet" "splash" ];
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };
    plymouth.enable = true;
  };

  hardware = {
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
    graphics.enable = true;
    graphics.enable32Bit = true;
    enableAllFirmware = true;
  };

  services = {
    blueman.enable = true;
    fprintd.enable = true;
    getty.autologinUser = "victor";
    logind.settings.Login.HandlePowerKey = "ignore";
    libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        naturalScrolling = true;
        clickMethod = "clickfinger";
      };
    };
    xserver = {
      enable = true;
      videoDrivers = [ "amdgpu" ];
      displayManager.startx.enable = true;
      windowManager.awesome.enable = true;
      xkb = {
        layout = "us,bg";
        variant = ",bas_phonetic";
        options = "grp:win_space_toggle";
      };
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  security = {
    rtkit.enable = true;
    polkit.enable = true;
    pam.services.sudo.fprintAuth = true;
    pam.services.i3lock.fprintAuth = true;
  };

  users.users.victor = {
    isNormalUser = true;
    description = "Victor";
    shell = pkgs.bashInteractive;
    extraGroups = [ "audio" "docker" "input" "networkmanager" "video" "wheel" ];
  };

  programs = {
    bash.completion.enable = true;
    dconf.enable = true;
    nix-ld.enable = true;
    steam.enable = true;
    xss-lock.enable = true;
  };

  virtualisation = {
    docker.enable = true;
    oci-containers = {
      backend = "docker";
      containers.ollama = {
        image = "ollama/ollama";
        autoStart = true;
        ports = [ "11434:11434" ];
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
    systemPackages = packageSet.available;
    sessionVariables = lib.optionalAttrs (lib.hasAttrByPath [ "oh-my-bash" ] pkgs) {
      OSH = "${pkgs.oh-my-bash}/share/oh-my-bash";
    };
  };

  fonts = {
    fontconfig.enable = true;
    packages = map (name: packageSet.byName.${name})
      (builtins.filter (name: builtins.hasAttr name packageSet.byName) [
        "Monocraft Nerd Font"
        "noto-fonts"
        "noto-fonts-cjk"
        "noto-fonts-emoji"
        "noto-fonts-extra"
      ]);
  };

  system.stateVersion = "26.05";
}

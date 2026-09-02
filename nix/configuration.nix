{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  monocraft = pkgs.stdenvNoCC.mkDerivation {
    pname = "monocraft-nerd-font-patched";
    version = "4.0";
    src = pkgs.fetchurl {
      url = "https://github.com/IdreesInc/Monocraft/releases/download/v4.0/Monocraft-nerd-fonts-patched.ttc";
      hash = "sha256-lYAb8hgmv4VyrzeHr4LnfuSN9L+4fpDEMX/P++fq8Dc=";
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm444 "$src" "$out/share/fonts/truetype/Monocraft-nerd-fonts-patched.ttc"
      runHook postInstall
    '';
  };

  hexagonHud = pkgs.runCommand "plymouth-theme-hexagon-hud" { } ''
    mkdir -p "$out/share/plymouth/themes/hexagon_hud"
    cp -R ${inputs.plymouth-themes}/pack_2/hexagon_hud/. \
      "$out/share/plymouth/themes/hexagon_hud/"

    # The upstream Arch-oriented metadata uses /usr/share. Point it at the
    # package so the NixOS Plymouth module can rewrite it for the initrd.
    substituteInPlace \
      "$out/share/plymouth/themes/hexagon_hud/hexagon_hud.plymouth" \
      --replace-fail "/usr/share/plymouth/themes/hexagon_hud" \
        "$out/share/plymouth/themes/hexagon_hud"
  '';

  vimixCursor = import ./cursor-theme.nix { inherit pkgs; };

  palette = {
    background = "#191919";
    foreground = "#f8f8f2";
    muted = "#404040";
    accent = "#67ffeb";
    warning = "#ff025f";
  };

  # Keep Astronaut's controls and typography, but disable its image layer so
  # the theme renders its palette.window color as the background instead.
  sddmAstronaut =
    (pkgs.sddm-astronaut.override {
      embeddedTheme = "astronaut";
      themeConfig = {
        Background = "";
        BackgroundPlaceholder = "";
        BackgroundColor = palette.background;
        DimBackgroundColor = palette.background;
        FormBackgroundColor = palette.background;
        Font = "Monocraft Nerd Font";
        FontSize = "13";
        RoundCorners = "8";
        HeaderText = "VIKING";
        HeaderTextColor = palette.foreground;
        DateTextColor = palette.accent;
        TimeTextColor = palette.accent;
        LoginFieldBackgroundColor = palette.background;
        PasswordFieldBackgroundColor = palette.background;
        LoginFieldTextColor = palette.foreground;
        PasswordFieldTextColor = palette.foreground;
        UserIconColor = palette.foreground;
        PasswordIconColor = palette.foreground;
        PlaceholderTextColor = palette.muted;
        WarningColor = palette.warning;
        LoginButtonTextColor = palette.background;
        LoginButtonBackgroundColor = palette.accent;
        SystemButtonsIconsColor = palette.foreground;
        SessionButtonTextColor = palette.foreground;
        VirtualKeyboardButtonTextColor = palette.foreground;
        DropdownTextColor = palette.foreground;
        DropdownSelectedBackgroundColor = palette.accent;
        DropdownBackgroundColor = palette.background;
        HighlightTextColor = palette.background;
        HighlightBackgroundColor = palette.accent;
        # The username icon overlaps this border by a few pixels in Astronaut.
        # Matching the field background removes the visible blue sliver.
        HighlightBorderColor = palette.background;
        HoverUserIconColor = palette.accent;
        HoverPasswordIconColor = palette.accent;
        HoverSystemButtonsIconsColor = palette.accent;
        HoverSessionButtonTextColor = palette.accent;
        HoverVirtualKeyboardButtonTextColor = palette.accent;
        PartialBlur = "false";
        FullBlur = "false";
        HaveFormBackground = "false";
        FormPosition = "center";
        PasswordFocus = "true";
        ForceLastUser = "true";
        HideCompletePassword = "true";
      };
    }).overrideAttrs
      (oldAttrs: {
        installPhase = oldAttrs.installPhase + ''
          theme_dir="$out/share/sddm/themes/sddm-astronaut-theme"
          chmod u+w "$theme_dir" "$theme_dir/Main.qml"
          substituteInPlace \
            "$theme_dir/Main.qml" \
            --replace-fail \
              'backgroundImage.source = config.background || config.Background' \
              'backgroundImage.visible = false'
        '';
      });

  fingerprintSetup = pkgs.writeShellApplication {
    name = "fingerprint-setup";
    runtimeInputs = with pkgs; [
      fprintd
      usbutils
    ];
    text = ''
      set -euo pipefail

      user_name="''${1:-$USER}"
      printf 'Existing fingerprints for %s:\n' "$user_name"
      fprintd-list "$user_name" || true
      printf '\nEnroll the right index finger:\n'
      if ! fprintd-enroll --finger right-index-finger "$user_name"; then
        printf '\nEnrollment failed. USB devices visible to libfprint diagnostics:\n' >&2
        lsusb >&2
        exit 1
      fi
      printf '\nVerify it:\n'
      fprintd-verify --finger right-index-finger "$user_name"
    '';
  };

  rebootToBootMenu = pkgs.writeShellApplication {
    name = "reboot-to-boot-menu";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      exec systemctl reboot --boot-loader-menu=30s
    '';
  };
in
{
  imports = [
    ./packages.nix
  ]
  ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix
  ++ lib.optional (builtins.pathExists ./disk-config.nix) ./disk-config.nix;

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  boot = {
    initrd = {
      kernelModules = [ "amdgpu" ];
      systemd.enable = true;
      verbose = false;
    };
    kernelParams = [
      # Disable PSR, adaptive backlight power transitions, and the broken
      # firmware-provided brightness curve. AC/DC events otherwise make the
      # AMD display stack retrain its power-saving state and visibly stall.
      "amdgpu.dcdebugmask=0x40010"
      "amdgpu.abmlevel=0"
      # Keep the CPU energy preference stable across AC/DC events. A power
      # profile is selected explicitly through power-profiles-daemon instead.
      "amd_pstate=active"
      "amd_dynamic_epp=disable"
      "quiet"
      "splash"
      "rd.udev.log_level=3"
      "rd.systemd.show_status=auto"
      "systemd.show_status=auto"
    ];
    consoleLogLevel = 3;
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        consoleMode = "auto";
        editor = false;
      };
      # Keep the menu invisible during normal boots. Hold Space before the
      # firmware hands off to systemd-boot to reveal all retained generations.
      timeout = 0;
    };

    plymouth = {
      enable = true;
      theme = "hexagon_hud";
      themePackages = [ hexagonHud ];
      font = "${monocraft}/share/fonts/truetype/Monocraft-nerd-fonts-patched.ttc";
    };
  };

  networking = {
    hostName = "nixfwbtw";
    useDHCP = false;
    dhcpcd.enable = false;
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    nftables.enable = true;
    firewall.enable = true;
    networkmanager = {
      enable = true;
      dns = "default";
      settings = {
        # Do not let DHCP-provided router DNS override the global resolvers.
        connection = {
          "ipv4.ignore-auto-dns" = true;
          "ipv6.ignore-auto-dns" = true;
        };
        global-dns.searches = "~.";
        "global-dns-domain-*".servers = "1.1.1.1,1.0.0.1";
      };
    };
  };

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users = {
    mutableUsers = true;
    users = {
      root.hashedPassword = "!";
      victor = {
        isNormalUser = true;
        description = "Victor";
        extraGroups = [
          "docker"
          "networkmanager"
          "video"
          "wheel"
        ];
        shell = pkgs.bashInteractive;
      };
    };
  };

  services.displayManager = {
    defaultSession = "hyprland-uwsm";
    autoLogin = {
      enable = true;
      user = "victor";
    };
    sddm = {
      enable = true;
      enableHidpi = true;
      package = pkgs.kdePackages.sddm;
      extraPackages = with pkgs.kdePackages; [
        qtmultimedia
        qtsvg
        qtvirtualkeyboard
      ];
      theme = "sddm-astronaut-theme";
      settings.Theme = {
        CursorTheme = "Vimix-Monocraft";
        CursorSize = 24;
      };
      wayland.enable = true;
    };
  };

  services.logind.settings.Login.HandlePowerKey = "ignore";

  programs = {
    dconf.enable = true;
    firefox = {
      enable = true;
      preferences = {
        "browser.theme.content-theme" = 0;
        "browser.theme.toolbar-theme" = 0;
        "font.name.monospace.x-western" = "Monocraft Nerd Font";
        "widget.gtk.libadwaita-colors.enabled" = true;
      };
    };
    fuse.userAllowOther = true;
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };
    hyprlock.enable = true;
    steam.enable = true;
  };

  security = {
    pam.services = {
      # Fingerprint authentication is intentionally limited to Hyprlock and
      # sudo; SDDM and the console login remain password-only.
      hyprlock.fprintAuth = true;
      login.fprintAuth = false;
      sddm.fprintAuth = false;
      sudo.fprintAuth = true;
    };
    polkit.enable = true;
    rtkit.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.hyprland.default = lib.mkForce [
      "hyprland"
      "gtk"
    ];
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    enableRedistributableFirmware = true;
    firmware = [ pkgs.sof-firmware ];
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  services = {
    blueman.enable = true;
    fprintd.enable = true;
    power-profiles-daemon.enable = true;
    llama-cpp = {
      enable = true;
      # Vulkan works on the laptop's AMD graphics without ROCm's supported-GPU
      # target restrictions.
      package = pkgs.llama-cpp.override { vulkanSupport = true; };
      settings = {
        hf-repo = "unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M";
        alias = "qwen3.8:27b";
        flash-attn = "on";
      };
    };
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
  };

  # GPU backends need a writable HOME for their shader cache. Without these,
  # llama-server exits immediately under the hardened DynamicUser service.
  systemd.services.llama-cpp = {
    environment = {
      HOME = "/var/cache/llama-cpp";
      XDG_CACHE_HOME = "/var/cache/llama-cpp";
    };
    serviceConfig.RestartSec = lib.mkForce "5s";
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  fonts = {
    packages = with pkgs; [
      monocraft
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      monospace = [ "Monocraft Nerd Font" ];
      sansSerif = [ "Monocraft Nerd Font" ];
      serif = [ "Monocraft Nerd Font" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  environment = {
    systemPackages = [
      fingerprintSetup
      rebootToBootMenu
      sddmAstronaut
      vimixCursor
    ];
    etc.inputrc.text = ''
      set completion-ignore-case on
      "\C-H": "\C-W"
    '';
    sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_QPA_PLATFORMTHEME = "qt6ct";
      TERMINAL = "alacritty";
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };
  };

  system.stateVersion = "26.05";
}

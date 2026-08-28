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

  palette = {
    background = "#191919";
    foreground = "#f8f8f2";
    muted = "#404040";
    accent = "#67ffeb";
    warning = "#ff025f";
  };

  sddmAstronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "astronaut";
    themeConfig = {
      # Keep Astronaut's layout and use the palette shared by the rest of this
      # configuration. An empty background deliberately removes the bundled
      # astronaut artwork.
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
      HighlightBorderColor = palette.accent;
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
  };

  vimixCursor = import ./cursor-theme.nix { inherit pkgs; };
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
      # Disable PSR and the broken firmware-provided brightness curve. The
      # latter otherwise wraps the top two brightness steps back to dim.
      "amdgpu.dcdebugmask=0x40010"
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
      };
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
    nameservers = [ "1.1.1.1" ];
    networkmanager = {
      enable = true;
      dns = "none";
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
    kwybars = {
      enable = true;
      settings = {
        overlay = {
          monitor_mode = "all";
          layer = "background";
          position = "bottom";
          full_length = true;
          height = 260;
          anchor_margin = 0;
          margin_left = 24;
          margin_right = 24;
          margin_bottom = 12;
          fade_in_ms = 300;
          fade_out_ms = 700;
        };
        visualizer = {
          backend = "pipewire";
          layout = "wave";
          bars = 24;
          framerate = 60;
          wave_stroke_width = 5;
          wave_fill = true;
          wave_glow = true;
          wave_smoothing = 2.0;
          wave_motion_smoothing = 0.14;
          wave_amplitude = 0.75;
          color_mode = "gradient";
          color_rgba = "rgba(103, 255, 235, 0.72)";
          color2_rgba = "rgba(162, 243, 0, 0.48)";
        };
        daemon = {
          enabled = true;
          poll_interval_ms = 50;
          activity_threshold = 0.025;
          activate_delay_ms = 120;
          deactivate_delay_ms = 1800;
          stop_on_silence = true;
          notify_on_error = true;
          notify_cooldown_seconds = 45;
        };
      };
      # Install a managed unit, but preserve Super+G as the explicit on/off
      # control instead of starting the visualizer on every login.
      systemd.enable = true;
    };
    steam.enable = true;
  };

  systemd.user.services.kwybars-daemon.wantedBy = lib.mkForce [ ];

  security = {
    pam.services = {
      # Hyprlock performs fingerprint scanning in parallel with its password
      # prompt. PAM remains password-only there to avoid two fprintd clients.
      hyprlock.fprintAuth = false;
      login.fprintAuth = true;
      sddm.fprintAuth = true;
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
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
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

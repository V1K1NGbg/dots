{ inputs, lib, pkgs, repoRoot, ... }:
let
  src = relative: repoRoot + "/${relative}";
  recursiveFile = relative: {
    source = src relative;
    recursive = true;
  };
  commonConfig = {
    "BetterDiscord" = recursiveFile "assets/config/BetterDiscord";
    "keepassxc" = recursiveFile "assets/config/keepassxc";
    "opencode" = recursiveFile "assets/config/opencode";
    "rofi" = recursiveFile "assets/config/rofi";
  };
  hyprConfig = {
    # Hyprland 0.55+ loads this Lua file as its compositor configuration.
    "hypr/hyprland.lua".source = src "assets/config/hypr/hyprland.lua";

    # These belong to separate Hypr ecosystem processes, not Hyprland itself.
    "hypr/hypridle.conf".source = src "assets/config/hypr/hypridle.conf";
    "hypr/hyprlock.conf".source = src "assets/config/hypr/hyprlock.conf";
    "hypr/hyprpaper.conf".source = src "assets/config/hypr/hyprpaper.conf";
    "hypr/hyprsunset.conf".source = src "assets/config/hypr/hyprsunset.conf";
    "hypr/wall.jpg".source = src "assets/config/hypr/wall.jpg";
    "mako" = recursiveFile "assets/config/mako";
    "satty" = recursiveFile "assets/config/satty";
  };
in
{
  imports = [ ./nemo.nix ];

  home = {
    username = "victor";
    homeDirectory = "/home/victor";
    stateVersion = "26.05";
    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
      TERMINAL = "alacritty";
      OSH = "${inputs.oh-my-bash-src}";
      XDG_SCREENSHOTS_DIR = "/home/victor/Pictures/Screenshots";
    };
    activation.createPersonalDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p \
        "$HOME/Documents/GitHub" \
        "$HOME/Pictures/Screenshots" \
        "$HOME/Documents/PC"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 0700 \
        "$HOME/.config/nixfwbtw/private" \
        "''${XDG_STATE_HOME:-$HOME/.local/state}/nixfwbtw/onboarding"
    '';
  };

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [ "ignoredups" "ignorespace" ];
    initExtra = builtins.readFile (src "assets/home/bashrc");
    shellAliases = {
      notes = "code -n ~/pCloudDrive/0Notes.md";
      config = "code -n ~/dots";
      lgit = "lazygit";
      mov-cli = "lobster";
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "V1K1NGbg";
      email = "victor@ilchev.com";
    };
  };

  programs.vim = {
    enable = true;
    extraConfig = builtins.readFile (src "assets/home/vimrc");
  };
  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile (src "assets/home/tmux.conf");
  };

  programs.alacritty = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile (src "assets/home/alacritty.toml"));
  };

  gtk = {
    enable = true;
    theme.name = "Adwaita-dark";
    iconTheme.name = "Adwaita";
    cursorTheme = {
      name = "capitaine-cursors";
      package = pkgs.capitaine-cursors;
    };
    font = {
      name = "Monocraft Nerd Font";
      size = 11;
    };
  };

  xdg = {
    enable = true;
    configFile = commonConfig // hyprConfig;
    userDirs = {
      enable = true;
      createDirectories = true;
      extraConfig.XDG_SCREENSHOTS_DIR = "$HOME/Pictures/Screenshots";
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/plain" = [ "code.desktop" ];
        "text/markdown" = [ "code.desktop" ];
        "application/json" = [ "code.desktop" ];
        "text/html" = [ "firefox.desktop" ];
        "application/xhtml+xml" = [ "firefox.desktop" ];
        "application/pdf" = [ "firefox.desktop" ];
        "video/mp4" = [ "vlc.desktop" ];
        "video/x-matroska" = [ "vlc.desktop" ];
        "audio/mpeg" = [ "vlc.desktop" ];
        "audio/flac" = [ "vlc.desktop" ];
        "image/png" = [ "gimp.desktop" ];
        "image/jpeg" = [ "gimp.desktop" ];
        "image/webp" = [ "gimp.desktop" ];
        "inode/directory" = [ "nemo.desktop" ];
      };
    };
  };

  home.file = {
    ".bash_profile".text = ''
      [[ -f ~/.bashrc ]] && . ~/.bashrc

      if [[ -z ''${WAYLAND_DISPLAY:-} && $(tty) == /dev/tty1 ]]; then
        command -v uwsm >/dev/null 2>&1 || {
          printf 'Hyprland is configured, but uwsm is unavailable.\n'
          return
        }
        exec uwsm start hyprland-uwsm.desktop
      fi
    '';
    ".vim/colors/monokai.vim".source = src "assets/home/vim/colors/monokai.vim";
    ".inputrc".text = ''
      "\C-H": backward-kill-word
    '';
    ".oh-my-bash/themes/agnoster/agnoster.theme.sh".source =
      src "assets/home/oh-my-bash/agnoster.theme.sh";
  };
}

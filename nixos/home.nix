{ config, lib, pkgs, ... }:

let
  packageSet = import ./packages.nix { inherit lib pkgs; };
  configDirectories = [
    "BetterDiscord"
    "alacritty"
    "autorandr"
    "awesome"
    "flameshot"
    "fusuma"
    "glava"
    "gtk-3.0"
    "keepassxc"
    "opencode"
    "picom"
    "rofi"
    "spicetify"
  ];
in
{
  home = {
    username = "victor";
    homeDirectory = "/home/victor";
    stateVersion = "26.05";
    packages = packageSet.available;
    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
      TERMINAL = "alacritty";
    };
    file = {
      ".bashrc".source = ../.bashrc;
      ".bash_profile".source = ../.bash_profile;
      ".tmux.conf".source = ../.tmux.conf;
      ".vimrc".source = ../.vimrc;
      ".Xresources".source = ../.Xresources;
      "i3lock.sh" = {
        source = ../i3lock.sh;
        executable = true;
      };
      ".vim" = {
        source = ../.vim;
        recursive = true;
      };
      ".screenlayout" = {
        source = ../.screenlayout;
        recursive = true;
      };
      ".oh-my-bash" = {
        source = ../.oh-my-bash;
        recursive = true;
      };
    };
  };

  xdg = {
    enable = true;
    configFile = lib.genAttrs configDirectories (name: {
      source = ../.config + "/${name}";
      recursive = true;
    }) // {
      "awesome/const.lua".text = ''
        local const = {}
        const.APPID = ""
        const.lat = 0.0000
        const.lon = 0.0000
        return const
      '';
    };
    dataFile = {
      "dots/imports/nemo_config".source = ../nemo_config;
      "dots/imports/copyq.cpq".source = ../copyq.cpq;
      "dots/imports/vimium-options.json".source = ../vimium-options.json;
      "dots/imports/bonjourr-20.1.2.json".source = ../. + "/bonjourr-20.1.2 2024-11-07 19_41_39.json";
      "dots/imports/bonjourr-20.4.2.json".source = ../. + "/bonjourr-20.4.2 2025-05-09 23_59_13.json";
      "dots/imports/marketplace-settings.json".source = ../marketplace-settings-2025-09-29T22_09_50.571Z.json;
      "dots/docker-compose.yml".source = ../docker-compose.yml;
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = [ "firefox.desktop" ];
        "application/xhtml+xml" = [ "firefox.desktop" ];
        "application/pdf" = [ "firefox.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
        "text/plain" = [ "code.desktop" ];
        "inode/directory" = [ "nemo.desktop" ];
        "audio/mpeg" = [ "vlc.desktop" ];
        "video/mp4" = [ "vlc.desktop" ];
        "image/jpeg" = [ "gimp.desktop" ];
        "image/png" = [ "gimp.desktop" ];
      };
    };
    userDirs = {
      enable = true;
      createDirectories = true;
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "V1K1NGbg";
      email = "victor@ilchev.com";
    };
  };

  systemd.user.services.import-nemo-dotfiles = {
    Unit = {
      Description = "Apply the Nemo settings from the dots repository";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.writeShellScript "import-nemo-dotfiles" ''
        ${pkgs.dconf}/bin/dconf load /org/nemo/ < ${../nemo_config}
      ''}";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.activation.createDotfileDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p \
      ${lib.escapeShellArg "${config.home.homeDirectory}/Documents/BackUp/screenshots"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/Documents/PC"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/Documents/GitHub"}
  '';

  warnings = lib.optional (packageSet.missing != [ ])
    "Some requested desktop packages are unavailable in this nixpkgs revision: ${lib.concatStringsSep ", " packageSet.missing}";
}

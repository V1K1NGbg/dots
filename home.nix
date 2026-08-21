{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  ohMyBash = pkgs.runCommand "oh-my-bash-configured" { } ''
    cp -R ${inputs.oh-my-bash} "$out"
    chmod -R u+w "$out"
    cp ${./.oh-my-bash/themes/agnoster/agnoster.theme.sh} \
      "$out/themes/agnoster/agnoster.theme.sh"
  '';

  opencodeSource = lib.cleanSourceWith {
    src = ./.config/opencode;
    filter =
      path: type:
      let
        name = baseNameOf path;
      in
      (type != "directory" || name != "__pycache__") && !(lib.hasSuffix ".pyc" name);
  };

  loadNemoConfig = pkgs.writeShellScript "load-nemo-config" ''
    ${pkgs.dconf}/bin/dconf load /org/nemo/ < ${./nemo_config}
  '';
in
{
  home = {
    username = "victor";
    homeDirectory = "/home/victor";
    stateVersion = "26.05";

    file = {
      ".bashrc".source = ./.bashrc;
      ".tmux.conf".source = ./.tmux.conf;
      ".vimrc".source = ./.vimrc;
      ".vim".source = ./.vim;
      ".oh-my-bash".source = ohMyBash;

      ".config/alacritty".source = ./.config/alacritty;
      ".config/keepassxc".source = ./.config/keepassxc;
      ".config/opencode".source = opencodeSource;
      ".config/rofi".source = ./.config/rofi;

      ".config/hypr".source = ./.config/hypr;
      ".config/mako".source = ./.config/mako;
      ".config/waybar".source = ./.config/waybar;
      ".config/Code/User/settings.json".source = ./.config/Code/User/settings.json;

      ".config/gtk-3.0/gtk.css".source = ./.config/gtk-3.0/gtk.css;
      ".config/gtk-4.0/gtk.css".source = ./.config/gtk-4.0/gtk.css;
      ".config/qt5ct/qt5ct.conf".source = ./.config/qt5ct/qt5ct.conf;
      ".config/qt5ct/colors/monocraft.conf".source = ./.config/qt5ct/colors/monocraft.conf;
      ".config/qt6ct/qt6ct.conf".source = ./.config/qt6ct/qt6ct.conf;
      ".config/qt6ct/colors/monocraft.conf".source = ./.config/qt6ct/colors/monocraft.conf;
    };
  };

  gtk = {
    enable = true;
    font = {
      name = "Monocraft Nerd Font";
      size = 10;
    };
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "capitaine-cursors";
      package = pkgs.capitaine-cursors;
      size = 24;
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "V1K1NGbg";
      email = "victor@ilchev.com";
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "nemo.desktop" ];
      "text/html" = [ "firefox.desktop" ];
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
    };
  };

  systemd.user.services = {
    hyprpolkitagent = {
      Unit = {
        Description = "Hyprland PolicyKit authentication agent";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe pkgs.hyprpolkitagent;
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    nemo-settings = {
      Unit = {
        Description = "Load the declarative Nemo preferences";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${loadNemoConfig}";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}

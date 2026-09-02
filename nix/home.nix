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
    cp ${../config/.oh-my-bash/themes/agnoster/agnoster.theme.sh} \
      "$out/themes/agnoster/agnoster.theme.sh"
  '';

  opencodeSource = lib.cleanSourceWith {
    src = ../config/.config/opencode;
    filter =
      path: type:
      let
        name = baseNameOf path;
      in
      (type != "directory" || name != "__pycache__") && !(lib.hasSuffix ".pyc" name);
  };

  loadNemoConfig = pkgs.writeShellScript "load-nemo-config" ''
    ${pkgs.dconf}/bin/dconf load /org/nemo/ < ${../config/nemo_config}
  '';

  sourcedFiles = [
    ".bashrc"
    ".tmux.conf"
    ".vimrc"
    ".vim"
    ".config/alacritty"
    ".config/keepassxc"
    ".config/rofi"
    ".config/hypr"
    ".config/mako"
    ".config/waybar"
    ".config/gtk-3.0/gtk.css"
    ".config/gtk-4.0/gtk.css"
    ".config/qt5ct/qt5ct.conf"
    ".config/qt5ct/colors/monocraft.conf"
    ".config/qt6ct/qt6ct.conf"
    ".config/qt6ct/colors/monocraft.conf"
  ];

  vimixCursor = import ./cursor-theme.nix { inherit pkgs; };
in
{
  home = {
    username = "victor";
    homeDirectory = "/home/victor";
    stateVersion = "26.05";

    file =
      lib.genAttrs sourcedFiles (name: {
        source = ../config + "/${name}";
      })
      // {
        ".oh-my-bash".source = ohMyBash;
        ".config/opencode" = {
          source = opencodeSource;
          recursive = true;
        };
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
      name = "Vimix-Monocraft";
      package = vimixCursor;
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
    hyprsunset = {
      Unit = {
        Description = "Always-on Hyprland blue-light filter";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe pkgs.hyprsunset;
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

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

  # OpenCode currently turns invalid credentials and a damaged SQLite state
  # into the same generic ProcessTicksAndRejections error. Credentials are not
  # used by the local provider; keep a recoverable backup of stale state.
  home.activation.repairOpenCodeAuth = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    state_dir="$HOME/.local/share/opencode"
    auth_file="$HOME/.local/share/opencode/auth.json"
    if [[ -f "$auth_file" ]] && ! ${pkgs.jq}/bin/jq -e \
      'type == "object" and length == 0' "$auth_file" >/dev/null 2>&1; then
      backup_file="$auth_file.stale-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
      ${pkgs.coreutils}/bin/mv -- "$auth_file" "$backup_file"
      ${pkgs.coreutils}/bin/printf '{}\n' > "$auth_file"
    fi

    repair_marker="$state_dir/.nixos-state-repair-v1"
    if [[ ! -e "$repair_marker" ]]; then
      backup_dir="$state_dir/nixos-state-backup-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
      for state_file in opencode.db opencode.db-shm opencode.db-wal storage; do
        if [[ -e "$state_dir/$state_file" ]]; then
          ${pkgs.coreutils}/bin/mkdir -p "$backup_dir"
          ${pkgs.coreutils}/bin/mv -- "$state_dir/$state_file" "$backup_dir/$state_file"
        fi
      done
      cache_dir="$HOME/.cache/opencode"
      if [[ -e "$cache_dir" ]]; then
        ${pkgs.coreutils}/bin/mkdir -p "$backup_dir"
        ${pkgs.coreutils}/bin/mv -- "$cache_dir" "$backup_dir/cache"
      fi
      ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
      ${pkgs.coreutils}/bin/touch "$repair_marker"
    fi
  '';
}

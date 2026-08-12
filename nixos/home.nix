{
  config,
  lib,
  pkgs,
  ...
}:

let
  staticConfigDirectories = [
    "alacritty"
    "fusuma"
    "glava"
    "opencode"
    "rofi"
    "spicetify"
  ];

  configFilesFrom =
    relativeDirectory: targetPrefix: predicate:
    let
      directory = ../. + "/${relativeDirectory}";
      entries = builtins.readDir directory;
      names = builtins.filter (name: entries.${name} == "regular" && predicate name) (
        builtins.attrNames entries
      );
    in
    builtins.listToAttrs (
      map (name: {
        name = "${targetPrefix}/${name}";
        value.source = directory + "/${name}";
      }) names
    );

  betterDiscordPlugins = configFilesFrom ".config/BetterDiscord/plugins" "BetterDiscord/plugins" (
    name: lib.hasSuffix ".plugin.js" name
  );
  betterDiscordThemes = configFilesFrom ".config/BetterDiscord/themes" "BetterDiscord/themes" (
    name: lib.hasSuffix ".theme.css" name
  );

  hyprlandFiles = {
    "hypr/hyprland.lua".source = ./hypr/hyprland.lua;
    "hypr/hypridle.conf".source = ./hypr/hypridle.conf;
    "hypr/hyprlock.conf".source = ./hypr/hyprlock.conf;
    "hypr/hyprsunset.conf".source = ./hypr/hyprsunset.conf;
    "uwsm/env".source = ./hypr/uwsm-env;
    "waybar/config.jsonc".source = ./hypr/waybar.jsonc;
    "waybar/style.css".source = ./hypr/waybar.css;
  };
in
{
  home = {
    username = "victor";
    homeDirectory = "/home/victor";
    stateVersion = "26.05";
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
      ".vim" = {
        source = ../.vim;
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
    configFile =
      lib.genAttrs staticConfigDirectories (name: {
        source = ../.config + "/${name}";
        recursive = true;
      })
      // betterDiscordPlugins
      // betterDiscordThemes
      // hyprlandFiles
      // {
        "gtk-3.0/settings.ini".source = ../.config/gtk-3.0/settings.ini;
      };

    dataFile = {
      "dots/imports/nemo_config".source = ../nemo_config;
      "dots/imports/copyq.cpq".source = ../copyq.cpq;
      "dots/imports/vimium-options.json".source = ../vimium-options.json;
      "dots/imports/bonjourr-20.1.2.json".source = ../. + "/bonjourr-20.1.2 2024-11-07 19_41_39.json";
      "dots/imports/bonjourr-20.4.2.json".source = ../. + "/bonjourr-20.4.2 2025-05-09 23_59_13.json";
      "dots/imports/marketplace-settings.json".source =
        ../marketplace-settings-2025-09-29T22_09_50.571Z.json;
      "dots/imports/keepassxc.ini".source = ../.config/keepassxc/keepassxc.ini;
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

  programs.readline = {
    enable = true;
    extraConfig = ''
      "\C-H": backward-kill-word
    '';
  };

  # Create writable initial state, but never overwrite changes made by apps.
  # Only executable plugin/theme code is declaratively linked above.
  home.activation.seedMutableApplicationConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    betterdiscord_destination=${lib.escapeShellArg "${config.xdg.configHome}/BetterDiscord/plugins"}
    $DRY_RUN_CMD mkdir -p "$betterdiscord_destination"

    betterdiscord_seed=${lib.escapeShellArg (toString ../.config/BetterDiscord/plugins)}
    while IFS= read -r seed; do
      relative="''${seed#"$betterdiscord_seed"/}"
      destination="$betterdiscord_destination/$relative"
      if [[ ! -e "$destination" ]]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$destination")"
        $DRY_RUN_CMD install -m 0600 "$seed" "$destination"
      fi
    done < <(${pkgs.findutils}/bin/find "$betterdiscord_seed" -type f -name '*.config.json' -print)

    flameshot_destination=${lib.escapeShellArg "${config.xdg.configHome}/flameshot/flameshot.ini"}
    if [[ ! -e "$flameshot_destination" ]]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$flameshot_destination")"
      $DRY_RUN_CMD install -m 0600 ${lib.escapeShellArg (toString ../.config/flameshot/flameshot.ini)} "$flameshot_destination"
    fi

    gtk_bookmarks_destination=${lib.escapeShellArg "${config.xdg.configHome}/gtk-3.0/bookmarks"}
    if [[ ! -e "$gtk_bookmarks_destination" ]]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$gtk_bookmarks_destination")"
      $DRY_RUN_CMD install -m 0600 ${lib.escapeShellArg (toString ../.config/gtk-3.0/bookmarks)} "$gtk_bookmarks_destination"
    fi

    keepass_destination=${lib.escapeShellArg "${config.xdg.configHome}/keepassxc/keepassxc.ini"}
    if [[ ! -e "$keepass_destination" ]]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$keepass_destination")"
      $DRY_RUN_CMD install -m 0600 ${lib.escapeShellArg (toString ../.config/keepassxc/keepassxc.ini)} "$keepass_destination"
    fi

  '';

  home.activation.createDotfileDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p \
      ${lib.escapeShellArg "${config.home.homeDirectory}/Documents/BackUp/screenshots"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/Documents/PC"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/Documents/GitHub"}
  '';
}

{ pkgs, ... }:

let
  rofiWithPlugins = pkgs.rofi.override {
    plugins = [ pkgs.rofi-calc ];
  };

  opencodeWithLocalModel = pkgs.writeShellApplication {
    name = "opencode";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      systemd
    ];
    text = ''
      case "''${1:-}" in
        --help|-h|--version|-v|completion)
          exec ${pkgs.opencode}/bin/opencode "$@"
          ;;
      esac

      endpoint=http://127.0.0.1:8080
      printf '%s\n' 'Waiting for the local Qwen3.8 model to become ready...'

      until curl --fail --silent --show-error "$endpoint/health" >/dev/null 2>&1; do
        if ! systemctl is-active --quiet llama-cpp.service; then
          printf '%s\n' \
            'OpenCode cannot start because llama-cpp.service is not running.' \
            'Run: systemctl status llama-cpp.service' \
            'Then: journalctl -u llama-cpp.service -b --no-pager' >&2
          exit 1
        fi

        sleep 2
      done

      exec ${pkgs.opencode}/bin/opencode "$@"
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    acpi
    alacritty
    alsa-utils
    ani-cli
    (aspellWithDicts (dicts: [ dicts.en ]))
    baobab
    bash-completion
    black
    blueman
    bluez
    btop
    brightnessctl
    bulky
    cliphist
    clang-tools
    cowsay
    curl
    discord
    docker-compose
    fastfetch
    fd
    firefox
    fprintd
    fnm
    git
    github-cli
    gnome-disk-utility
    go
    gopls
    grim
    highlight
    htop
    hypridle
    hyprlock
    hyprpolkitagent
    hyprsunset
    imgcat
    jdk21
    jdk8
    keepassxc
    lazygit
    less
    libconfig
    libinput
    libnotify
    libqalculate
    (llama-cpp.override { vulkanSupport = true; })
    localsend
    lolcat
    mako
    man-db
    man-pages
    meld
    nano
    nemo-with-extensions
    networkmanagerapplet
    nixos-firewall-tool
    nmap
    nvtopPackages.amd
    nwg-displays
    nwg-look
    opencodeWithLocalModel
    papirus-icon-theme
    pavucontrol
    pcloud
    playerctl
    poppler-utils
    prettier
    prismlauncher
    pyright
    python3
    qalculate-gtk
    ranger
    rust-analyzer
    rustfmt
    slurp
    spotify
    swappy
    tmux
    tree
    typescript-language-server
    unzip
    usbimager
    uthash
    vim
    vlc
    vscode
    vulkan-tools
    waybar
    wev
    wget
    wireplumber
    wl-clipboard
    wtype
    ydotool
    zip
    nodejs

    adw-gtk3
    kdePackages.qt6ct
    libsForQt5.qt5ct
    xdg-utils
    rofiWithPlugins
  ];
}

{ inputs, pkgs, ... }:
let
  lobster = inputs.lobster.packages.${pkgs.stdenv.hostPlatform.system}.lobster;
in
{
  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs; [
    monocraft-nerd-font
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  environment.systemPackages = with pkgs; [
    acpi
    alacritty
    ani-cli
    baobab
    bash-completion
    bulky
    copyq
    cowsay
    curl
    discord
    docker-compose
    fastfetch
    fd
    firefox
    gh
    gimp
    git
    gnome-disk-utility
    highlight
    htop
    imagemagick
    jdk21
    jdk8
    keepassxc
    lazygit
    less
    lobster
    lolcat
    man-pages
    meld
    nano
    nemo
    nmap
    vtop
    nodejs_24
    nvtopPackages.amd
    opencode
    pavucontrol
    pcloud
    playerctl
    prismlauncher
    python3
    ranger
    rofi-wayland-only
    spotify
    tmux
    tree
    unzip
    vim
    vlc
    vscode
    vulkan-tools
    wget
    zip
  ];

  environment.shellAliases = {
    lgit = "lazygit";
    mov-cli = "lobster";
  };

  environment.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
  };
}

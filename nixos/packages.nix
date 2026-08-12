{ lib, pkgs }:

let
  # If one of these cannot be resolved, evaluation fails. These packages are
  # part of the daily desktop workflow and must never disappear silently.
  requiredNames = [
    "alacritty"
    "copyq"
    "discord"
    "firefox"
    "flameshot"
    "github-cli"
    "keepassxc"
    "Monocraft Nerd Font"
    "nemo-compare"
    "network-manager-applet"
    "opencode"
    "pcloud-drive"
    "playerctl"
    "rofi"
    "rofi-calc"
    "ruby-fusuma"
    "spotify"
    "tmux"
    "vim"
    "visual-studio-code"
    "vlc"
  ];

  specs = [
    {
      name = "acpi";
      candidates = [ [ "acpi" ] ];
    }
    {
      name = "alacritty";
      candidates = [ [ "alacritty" ] ];
    }
    {
      name = "alsa-utils";
      candidates = [ [ "alsa-utils" ] ];
    }
    {
      name = "ani-cli";
      candidates = [ [ "ani-cli" ] ];
    }
    {
      name = "aspell";
      candidates = [ [ "aspell" ] ];
    }
    {
      name = "aspell-en";
      candidates = [
        [
          "aspellDicts"
          "en"
        ]
      ];
    }
    {
      name = "baobab";
      candidates = [ [ "baobab" ] ];
    }
    {
      name = "bash-completion";
      candidates = [ [ "bash-completion" ] ];
    }
    {
      name = "blueman";
      candidates = [ [ "blueman" ] ];
    }
    {
      name = "bluez";
      candidates = [ [ "bluez" ] ];
    }
    {
      name = "bluez-utils";
      candidates = [ [ "bluez" ] ];
    }
    {
      name = "bulky";
      candidates = [ [ "bulky" ] ];
    }
    {
      name = "capitaine-cursors";
      candidates = [ [ "capitaine-cursors" ] ];
    }
    {
      name = "copyq";
      candidates = [ [ "copyq" ] ];
    }
    {
      name = "cowsay";
      candidates = [ [ "cowsay" ] ];
    }
    {
      name = "cpupower-gui";
      candidates = [ [ "cpupower-gui" ] ];
    }
    {
      name = "curl";
      candidates = [ [ "curl" ] ];
    }
    {
      name = "discord";
      candidates = [ [ "discord" ] ];
    }
    {
      name = "docker";
      candidates = [ [ "docker" ] ];
    }
    {
      name = "docker-compose";
      candidates = [ [ "docker-compose" ] ];
    }
    {
      name = "dracut";
      candidates = [ [ "dracut" ] ];
    }
    {
      name = "fastfetch";
      candidates = [ [ "fastfetch" ] ];
    }
    {
      name = "fd";
      candidates = [ [ "fd" ] ];
    }
    {
      name = "firefox";
      candidates = [ [ "firefox" ] ];
    }
    {
      name = "flameshot";
      candidates = [ [ "flameshot" ] ];
    }
    {
      name = "fprintd";
      candidates = [ [ "fprintd" ] ];
    }
    {
      name = "gimp";
      candidates = [ [ "gimp" ] ];
    }
    {
      name = "git";
      candidates = [ [ "git" ] ];
    }
    {
      name = "github-cli";
      candidates = [ [ "gh" ] ];
    }
    {
      name = "glava";
      candidates = [ [ "glava" ] ];
    }
    {
      name = "gnome-disk-utility";
      candidates = [ [ "gnome-disk-utility" ] ];
    }
    {
      name = "highlight";
      candidates = [ [ "highlight" ] ];
    }
    {
      name = "htop";
      candidates = [ [ "htop" ] ];
    }
    {
      name = "imgcat";
      candidates = [ [ "imgcat" ] ];
    }
    {
      name = "jdk21-openjdk";
      candidates = [ [ "jdk21" ] ];
    }
    {
      name = "jdk8-openjdk";
      candidates = [ [ "jdk8" ] ];
    }
    {
      name = "keepassxc";
      candidates = [ [ "keepassxc" ] ];
    }
    {
      name = "lazygit";
      candidates = [ [ "lazygit" ] ];
    }
    {
      name = "less";
      candidates = [ [ "less" ] ];
    }
    {
      name = "libconfig";
      candidates = [ [ "libconfig" ] ];
    }
    {
      name = "lobster";
      candidates = [ [ "lobster" ] ];
    }
    {
      name = "localsend";
      candidates = [ [ "localsend" ] ];
    }
    {
      name = "lolcat";
      candidates = [ [ "lolcat" ] ];
    }
    {
      name = "man-db";
      candidates = [ [ "man-db" ] ];
    }
    {
      name = "man-pages";
      candidates = [ [ "man-pages" ] ];
    }
    {
      name = "meld";
      candidates = [ [ "meld" ] ];
    }
    {
      name = "nano";
      candidates = [ [ "nano" ] ];
    }
    {
      name = "nemo";
      candidates = [ [ "nemo" ] ];
    }
    {
      name = "nemo-compare";
      candidates = [ [ "nemo-with-extensions" ] ];
    }
    {
      name = "nemo-fileroller";
      candidates = [
        [ "nemo-fileroller" ]
        [ "file-roller" ]
      ];
    }
    {
      name = "network-manager-applet";
      candidates = [ [ "networkmanagerapplet" ] ];
    }
    {
      name = "nmap";
      candidates = [ [ "nmap" ] ];
    }
    {
      name = "noto-fonts";
      candidates = [ [ "noto-fonts" ] ];
    }
    {
      name = "noto-fonts-cjk";
      candidates = [
        [ "noto-fonts-cjk-sans" ]
        [ "noto-fonts-cjk" ]
      ];
    }
    {
      name = "noto-fonts-emoji";
      candidates = [ [ "noto-fonts-color-emoji" ] ];
    }
    # Merged into noto-fonts in this release; keep the logical name because it
    # is used by the font selection below.
    {
      name = "noto-fonts-extra";
      candidates = [ [ "noto-fonts" ] ];
    }
    {
      name = "nvtop";
      candidates = [
        [
          "nvtopPackages"
          "amd"
        ]
        [ "nvtop" ]
      ];
    }
    {
      name = "pasystray";
      candidates = [ [ "pasystray" ] ];
    }
    {
      name = "pavucontrol";
      candidates = [ [ "pavucontrol" ] ];
    }
    {
      name = "pcloud-drive";
      candidates = [ [ "pcloud" ] ];
    }
    {
      name = "playerctl";
      candidates = [ [ "playerctl" ] ];
    }
    {
      name = "plymouth";
      candidates = [ [ "plymouth" ] ];
    }
    {
      name = "prismlauncher";
      candidates = [ [ "prismlauncher" ] ];
    }
    {
      name = "qt6-svg";
      candidates = [
        [
          "qt6Packages"
          "qtsvg"
        ]
      ];
    }
    {
      name = "ranger";
      candidates = [ [ "ranger" ] ];
    }
    {
      name = "rofi";
      candidates = [ [ "rofi" ] ];
    }
    {
      name = "rofi-calc";
      candidates = [ [ "rofi-calc" ] ];
    }
    {
      name = "ruby-fusuma";
      # The pinned nixpkgs Fusuma bundle includes fusuma-plugin-sendkey and
      # revdev, so sendkey actions work without a separate Ruby installation.
      candidates = [ [ "fusuma" ] ];
    }
    {
      name = "sof-firmware";
      candidates = [ [ "sof-firmware" ] ];
    }
    # nixpkgs 26.05 has the official client, not spotify-launcher.
    {
      name = "spotify";
      candidates = [ [ "spotify" ] ];
    }
    {
      name = "steam";
      candidates = [ [ "steam" ] ];
    }
    {
      name = "tmux";
      candidates = [ [ "tmux" ] ];
    }
    {
      name = "tree";
      candidates = [ [ "tree" ] ];
    }
    {
      name = "unzip";
      candidates = [ [ "unzip" ] ];
    }
    {
      name = "usbimager";
      candidates = [ [ "usbimager" ] ];
    }
    {
      name = "uthash";
      candidates = [ [ "uthash" ] ];
    }
    {
      name = "vim";
      candidates = [ [ "vim" ] ];
    }
    {
      name = "visual-studio-code";
      candidates = [ [ "vscode" ] ];
    }
    {
      name = "vlc";
      candidates = [ [ "vlc" ] ];
    }
    {
      name = "vulkan-radeon";
      candidates = [ [ "mesa" ] ];
    }
    {
      name = "vulkan-tools";
      candidates = [ [ "vulkan-tools" ] ];
    }
    {
      name = "wget";
      candidates = [ [ "wget" ] ];
    }
    {
      name = "zip";
      candidates = [ [ "zip" ] ];
    }

    # Commands referenced by the checked-in configs but absent from install.sh.
    {
      name = "libqalculate";
      candidates = [ [ "libqalculate" ] ];
    }
    {
      name = "xsel";
      candidates = [ [ "xsel" ] ];
    }
    {
      name = "iputils";
      candidates = [ [ "iputils" ] ];
    }
    {
      name = "opencode";
      candidates = [ [ "opencode" ] ];
    }
    {
      name = "nodejs";
      candidates = [ [ "nodejs" ] ];
    }
    # vtop is no longer in nixpkgs; btop covers the same monitoring goal.
    {
      name = "btop";
      candidates = [ [ "btop" ] ];
    }
    {
      name = "prettier";
      candidates = [ [ "prettier" ] ];
    }
    {
      name = "typescript-language-server";
      candidates = [ [ "typescript-language-server" ] ];
    }
    {
      name = "pyright";
      candidates = [ [ "pyright" ] ];
    }
    {
      name = "black";
      candidates = [ [ "black" ] ];
    }
    {
      name = "clang-tools";
      candidates = [ [ "clang-tools" ] ];
    }
    {
      name = "shfmt";
      candidates = [ [ "shfmt" ] ];
    }
    {
      name = "rust-analyzer";
      candidates = [ [ "rust-analyzer" ] ];
    }
    {
      name = "rustfmt";
      candidates = [
        [ "rustfmt" ]
        [ "rustc" ]
      ];
    }
    {
      name = "go";
      candidates = [ [ "go" ] ];
    }
    {
      name = "gopls";
      candidates = [ [ "gopls" ] ];
    }
    {
      name = "python3";
      candidates = [ [ "python3" ] ];
    }

    {
      name = "Monocraft Nerd Font";
      candidates = [
        [ "monocraft" ]
        [
          "nerd-fonts"
          "monocraft"
        ]
      ];
    }
  ];

  resolve =
    spec:
    let
      paths = builtins.filter (path: lib.hasAttrByPath path pkgs) spec.candidates;
      values = map (path: lib.getAttrFromPath path pkgs) paths;
      packages = builtins.filter lib.isDerivation values;
    in
    if packages == [ ] then null else builtins.head packages;

  resolved = map (
    spec:
    spec
    // {
      package = resolve spec;
      required = builtins.elem spec.name requiredNames;
    }
  ) specs;
  present = builtins.filter (spec: spec.package != null) resolved;
  absent = builtins.filter (spec: spec.package == null) resolved;
  required = builtins.filter (spec: spec.required) present;
  optional = builtins.filter (spec: !spec.required) present;
  missingRequired = map (spec: spec.name) (builtins.filter (spec: spec.required) absent);
  missingOptional = map (spec: spec.name) (builtins.filter (spec: !spec.required) absent);
in
{
  all = map (spec: spec.package) present;
  required = map (spec: spec.package) required;
  optional = map (spec: spec.package) optional;
  byName = builtins.listToAttrs (
    map (spec: {
      inherit (spec) name;
      value = spec.package;
    }) present
  );
  inherit missingRequired missingOptional;
}

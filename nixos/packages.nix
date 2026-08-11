{ lib, pkgs }:

let
  specs = [
    { name = "acpi"; candidates = [ [ "acpi" ] ]; }
    { name = "alacritty"; candidates = [ [ "alacritty" ] ]; }
    { name = "alsa-utils"; candidates = [ [ "alsa-utils" ] ]; }
    { name = "ani-cli"; candidates = [ [ "ani-cli" ] ]; }
    { name = "arandr"; candidates = [ [ "arandr" ] ]; }
    { name = "aspell"; candidates = [ [ "aspell" ] ]; }
    { name = "aspell-en"; candidates = [ [ "aspellDicts" "en" ] ]; }
    { name = "autorandr"; candidates = [ [ "autorandr" ] ]; }
    { name = "awesome-git"; candidates = [ [ "awesome" ] ]; }
    { name = "baobab"; candidates = [ [ "baobab" ] ]; }
    { name = "bash-completion"; candidates = [ [ "bash-completion" ] ]; }
    { name = "blueman"; candidates = [ [ "blueman" ] ]; }
    { name = "bluez"; candidates = [ [ "bluez" ] ]; }
    { name = "bluez-utils"; candidates = [ [ "bluez" ] ]; }
    { name = "bulky"; candidates = [ [ "bulky" ] ]; }
    { name = "capitaine-cursors"; candidates = [ [ "capitaine-cursors" ] ]; }
    { name = "copyq"; candidates = [ [ "copyq" ] ]; }
    { name = "cowsay"; candidates = [ [ "cowsay" ] ]; }
    { name = "cpupower-gui"; candidates = [ [ "cpupower-gui" ] ]; }
    { name = "curl"; candidates = [ [ "curl" ] ]; }
    { name = "dangerzone"; candidates = [ [ "dangerzone" ] ]; }
    { name = "discord"; candidates = [ [ "discord" ] ]; }
    { name = "docker"; candidates = [ [ "docker" ] ]; }
    { name = "docker-compose"; candidates = [ [ "docker-compose" ] ]; }
    { name = "dracut"; candidates = [ [ "dracut" ] ]; }
    { name = "fastfetch"; candidates = [ [ "fastfetch" ] ]; }
    { name = "fd"; candidates = [ [ "fd" ] ]; }
    { name = "firefox"; candidates = [ [ "firefox" ] ]; }
    { name = "flameshot"; candidates = [ [ "flameshot" ] ]; }
    { name = "fprintd"; candidates = [ [ "fprintd" ] ]; }
    { name = "gimp"; candidates = [ [ "gimp" ] ]; }
    { name = "git"; candidates = [ [ "git" ] ]; }
    { name = "github-cli"; candidates = [ [ "gh" ] ]; }
    { name = "glava"; candidates = [ [ "glava" ] ]; }
    { name = "gnome-disk-utility"; candidates = [ [ "gnome-disk-utility" ] ]; }
    { name = "highlight"; candidates = [ [ "highlight" ] ]; }
    { name = "htop"; candidates = [ [ "htop" ] ]; }
    { name = "i3lock-color"; candidates = [ [ "i3lock-color" ] ]; }
    { name = "imgcat"; candidates = [ [ "imgcat" ] ]; }
    { name = "jdk21-openjdk"; candidates = [ [ "jdk21" ] ]; }
    { name = "jdk8-openjdk"; candidates = [ [ "jdk8" ] ]; }
    { name = "keepassxc"; candidates = [ [ "keepassxc" ] ]; }
    { name = "lazygit"; candidates = [ [ "lazygit" ] ]; }
    { name = "less"; candidates = [ [ "less" ] ]; }
    { name = "libconfig"; candidates = [ [ "libconfig" ] ]; }
    { name = "lobster"; candidates = [ [ "lobster" ] ]; }
    { name = "localsend"; candidates = [ [ "localsend" ] ]; }
    { name = "lolcat"; candidates = [ [ "lolcat" ] ]; }
    { name = "man-db"; candidates = [ [ "man-db" ] ]; }
    { name = "man-pages"; candidates = [ [ "man-pages" ] ]; }
    { name = "meld"; candidates = [ [ "meld" ] ]; }
    { name = "nano"; candidates = [ [ "nano" ] ]; }
    { name = "nemo"; candidates = [ [ "nemo" ] ]; }
    { name = "nemo-compare"; candidates = [ [ "nemo-with-extensions" ] ]; }
    { name = "nemo-fileroller"; candidates = [ [ "nemo-fileroller" ] [ "file-roller" ] ]; }
    { name = "network-manager-applet"; candidates = [ [ "networkmanagerapplet" ] ]; }
    { name = "nmap"; candidates = [ [ "nmap" ] ]; }
    { name = "noto-fonts"; candidates = [ [ "noto-fonts" ] ]; }
    { name = "noto-fonts-cjk"; candidates = [ [ "noto-fonts-cjk-sans" ] [ "noto-fonts-cjk" ] ]; }
    { name = "noto-fonts-emoji"; candidates = [ [ "noto-fonts-color-emoji" ] ]; }
    { name = "noto-fonts-extra"; candidates = [ [ "noto-fonts-extra" ] ]; }
    { name = "nvtop"; candidates = [ [ "nvtopPackages" "amd" ] [ "nvtop" ] ]; }
    { name = "pasystray"; candidates = [ [ "pasystray" ] ]; }
    { name = "pavucontrol"; candidates = [ [ "pavucontrol" ] ]; }
    { name = "pcloud-drive"; candidates = [ [ "pcloud" ] ]; }
    { name = "playerctl"; candidates = [ [ "playerctl" ] ]; }
    { name = "plymouth"; candidates = [ [ "plymouth" ] ]; }
    { name = "plymouth-theme-hexagon-hud-git"; candidates = [ [ "plymouth-theme-hexagon-hud" ] ]; }
    { name = "prismlauncher"; candidates = [ [ "prismlauncher" ] ]; }
    { name = "qt6-svg"; candidates = [ [ "qt6Packages" "qtsvg" ] ]; }
    { name = "ranger"; candidates = [ [ "ranger" ] ]; }
    { name = "redshift"; candidates = [ [ "redshift" ] ]; }
    { name = "rofi"; candidates = [ [ "rofi" ] ]; }
    { name = "rofi-calc"; candidates = [ [ "rofi-calc" ] ]; }
    { name = "ruby-fusuma"; candidates = [ [ "fusuma" ] ]; }
    { name = "ruby-fusuma-plugin-sendkey"; candidates = [ [ "rubyPackages" "fusuma-plugin-sendkey" ] ]; }
    { name = "sof-firmware"; candidates = [ [ "sof-firmware" ] ]; }
    { name = "spotify-launcher"; candidates = [ [ "spotify-launcher" ] ]; }
    { name = "steam"; candidates = [ [ "steam" ] ]; }
    { name = "tmux"; candidates = [ [ "tmux" ] ]; }
    { name = "tree"; candidates = [ [ "tree" ] ]; }
    { name = "unclutter"; candidates = [ [ "unclutter" ] ]; }
    { name = "unzip"; candidates = [ [ "unzip" ] ]; }
    { name = "usbimager"; candidates = [ [ "usbimager" ] ]; }
    { name = "uthash"; candidates = [ [ "uthash" ] ]; }
    { name = "vim"; candidates = [ [ "vim" ] ]; }
    { name = "visual-studio-code"; candidates = [ [ "vscode" ] ]; }
    { name = "vlc"; candidates = [ [ "vlc" ] ]; }
    { name = "vulkan-radeon"; candidates = [ [ "mesa" ] ]; }
    { name = "vulkan-tools"; candidates = [ [ "vulkan-tools" ] ]; }
    { name = "wget"; candidates = [ [ "wget" ] ]; }
    { name = "xdotool"; candidates = [ [ "xdotool" ] ]; }
    { name = "xorg-xev"; candidates = [ [ "xorg" "xev" ] ]; }
    { name = "xorg-xinput"; candidates = [ [ "xorg" "xinput" ] ]; }
    { name = "xorg-xset"; candidates = [ [ "xorg" "xset" ] ]; }
    { name = "xorg-setxkbmap"; candidates = [ [ "xorg" "setxkbmap" ] ]; }
    { name = "xorg-xrandr"; candidates = [ [ "xorg" "xrandr" ] ]; }
    { name = "xorg-xinit"; candidates = [ [ "xorg" "xinit" ] ]; }
    { name = "xss-lock"; candidates = [ [ "xss-lock" ] ]; }
    { name = "zip"; candidates = [ [ "zip" ] ]; }

    # Commands referenced by the checked-in configs but absent from install.sh.
    { name = "libqalculate"; candidates = [ [ "libqalculate" ] ]; }
    { name = "xsel"; candidates = [ [ "xsel" ] ]; }
    { name = "iputils"; candidates = [ [ "iputils" ] ]; }
    { name = "oh-my-bash"; candidates = [ [ "oh-my-bash" ] ]; }
    { name = "opencode"; candidates = [ [ "opencode" ] ]; }
    { name = "nodejs"; candidates = [ [ "nodejs" ] ]; }
    { name = "vtop"; candidates = [ [ "nodePackages" "vtop" ] ]; }
    { name = "prettier"; candidates = [ [ "nodePackages" "prettier" ] [ "prettier" ] ]; }
    { name = "typescript-language-server"; candidates = [ [ "nodePackages" "typescript-language-server" ] [ "typescript-language-server" ] ]; }
    { name = "pyright"; candidates = [ [ "pyright" ] [ "nodePackages" "pyright" ] ]; }
    { name = "black"; candidates = [ [ "black" ] ]; }
    { name = "clang-tools"; candidates = [ [ "clang-tools" ] ]; }
    { name = "shfmt"; candidates = [ [ "shfmt" ] ]; }
    { name = "rust-analyzer"; candidates = [ [ "rust-analyzer" ] ]; }
    { name = "rustfmt"; candidates = [ [ "rustfmt" ] [ "rustc" ] ]; }
    { name = "go"; candidates = [ [ "go" ] ]; }
    { name = "gopls"; candidates = [ [ "gopls" ] ]; }
    { name = "python3"; candidates = [ [ "python3" ] ]; }

    # The animation syntax in picom.conf requires the pijulius fork.
    { name = "picom-pijulius"; candidates = [ [ "picom-pijulius" ] [ "picom" ] ]; }
    { name = "Monocraft Nerd Font"; candidates = [ [ "nerd-fonts" "monocraft" ] [ "monocraft" ] ]; }
  ];

  resolve = spec:
    let
      paths = builtins.filter (path: lib.hasAttrByPath path pkgs) spec.candidates;
      values = map (path: lib.getAttrFromPath path pkgs) paths;
      packages = builtins.filter lib.isDerivation values;
    in
    if packages == [ ] then null else builtins.head packages;

  resolved = map (spec: spec // { package = resolve spec; }) specs;
  present = builtins.filter (spec: spec.package != null) resolved;
  absent = builtins.filter (spec: spec.package == null) resolved;
in
{
  available = map (spec: spec.package) present;
  byName = builtins.listToAttrs (map (spec: {
    inherit (spec) name;
    value = spec.package;
  }) present);
  missing = map (spec: spec.name) absent;
}

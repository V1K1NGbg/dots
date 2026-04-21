#!/bin/bash

# Pre-requisites (run manually before this script):
#   gpg --keyserver-options auto-key-retrieve --verify archlinux.iso.sig
#   sha256sum archlinux.iso
#   sudo usbimager
#
# Extra packages needed before running: git vim firefox less
#
# Fetch dots:
#   git clone https://github.com/V1K1NGbg/dots.git

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${HOME}/.local/share/archinstaller"
mkdir -p "$STATE_DIR"

# ==============================================================================
# COLORS & SYMBOLS
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

SEP="$(printf '═%.0s' {1..62})"
DIV="$(printf '─%.0s' {1..62})"

# ==============================================================================
# UTILITY
# ==============================================================================

print_header() {
    echo
    echo -e "${BOLD}${CYAN}${SEP}${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}${SEP}${NC}"
    echo
}

print_step()    { echo -e "  ${BLUE}▶${NC} $1"; }
print_success() { echo -e "  ${GREEN}✓${NC} $1"; }
print_error()   { echo -e "  ${RED}✗${NC} $1" >&2; }

mark_done()     { touch "${STATE_DIR}/$1.done"; }
is_marked()     { [[ -f "${STATE_DIR}/$1.done" ]]; }

cmd_exists()    { command -v "$1" &>/dev/null; }
pkg_installed() { pacman -Qq "$1" &>/dev/null 2>&1; }

# ==============================================================================
# CHECK FUNCTIONS  (return 0 = done, non-zero = not done)
# ==============================================================================

check_multilib()          { grep -q '^\[multilib\]' /etc/pacman.conf; }
check_system_updated()    { is_marked "system_updated"; }
check_paru()              { cmd_exists paru; }
check_awesome()           { pacman -Qq awesome-git &>/dev/null 2>&1; }
check_packages()          { pkg_installed alacritty && pkg_installed nemo && pkg_installed rofi && pkg_installed vim; }
check_autologin()         { [[ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]]; }
check_picom()             { cmd_exists picom; }
check_amd_gpu()           { grep -ql 'amdgpu.dcdebugmask' /boot/loader/entries/*.conf 2>/dev/null; }
check_plymouth()          { grep -ql 'splash' /boot/loader/entries/*.conf 2>/dev/null && grep -q 'plymouth' /etc/mkinitcpio.conf; }
check_power_button()      { grep -q '^HandlePowerKey=ignore' /etc/systemd/logind.conf; }
check_bluetooth()         { systemctl is-enabled bluetooth.service &>/dev/null; }
check_touchpad()          { grep -q 'Tapping' /usr/share/X11/xorg.conf.d/40-libinput.conf 2>/dev/null; }
check_keyboard_layout()   { grep -q 'us,bg' /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null; }
check_fusuma()            { [[ -d "${HOME}/.config/fusuma" ]] && id -nG "$USER" | grep -qw input; }
check_ctrl_backspace()    { grep -qF '"\C-H"' /etc/inputrc 2>/dev/null; }
check_monocraft()         { fc-list 2>/dev/null | grep -qi monocraft; }
check_dns()               { grep -q '1.1.1.1' /etc/NetworkManager/conf.d/dns-servers.conf 2>/dev/null; }
check_wireguard()         { nmcli connection show 2>/dev/null | grep -qi wireguard; }
check_git_config()        { [[ -n "$(git config --global user.name 2>/dev/null)" ]]; }
check_gh_auth()           { gh auth status &>/dev/null; }
check_fingerprint()       { grep -q 'pam_fprintd' /etc/pam.d/sudo 2>/dev/null; }
check_ohmybash()          { [[ -d "${HOME}/.oh-my-bash" ]]; }
check_bashrc()            { grep -q 'OSH_THEME="agnoster"' "${HOME}/.bashrc" 2>/dev/null; }
check_nemo_config()       { dconf read /org/nemo/preferences/bulk-rename-tool 2>/dev/null | grep -q 'bulky'; }
check_dotfiles()          { [[ -f "${HOME}/.vimrc" && -f "${HOME}/.tmux.conf" && -f "${HOME}/.Xresources" && -f "${HOME}/.bash_profile" && -d "${HOME}/.config/awesome" && -d "${HOME}/.config/alacritty" ]]; }
check_i3lock()            { [[ -x "${HOME}/i3lock.sh" ]]; }
check_default_apps()      { xdg-mime query default text/html 2>/dev/null | grep -q firefox; }
check_nvm()               { [[ -d "${HOME}/.nvm" ]]; }
check_vtop()              { cmd_exists vtop; }
check_docker()            { systemctl is-enabled docker.service &>/dev/null; }
check_pcloud()            { cmd_exists pcloud; }
check_awesome_const()     { is_marked "awesome_const"; }
check_discord()           { [[ -d "${HOME}/.config/BetterDiscord" ]]; }
check_spotify()           { grep -q 'current_theme.*=.*Ziro' "${HOME}/.config/spicetify/config-xpui.ini" 2>/dev/null; }
check_opencode()          { cmd_exists opencode; }
check_vscode()            { is_marked "vscode_setup"; }
check_copyq()             { [[ -f "${HOME}/.config/copyq/copyq.conf" ]]; }
check_firefox()           { is_marked "firefox_setup"; }
check_steam()             { is_marked "steam_setup"; }
check_docker_containers() { docker ps 2>/dev/null | grep -q ollama; }

# ==============================================================================
# INSTALL FUNCTIONS
# ==============================================================================

install_multilib() {
    print_header "Enabling multilib"
    print_step "Uncommenting [multilib] in /etc/pacman.conf..."
    sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
    print_success "multilib enabled"
}

install_system_update() {
    print_header "Updating System"
    sudo pacman -Syu
    mark_done "system_updated"
    print_success "System updated"
}

install_paru() {
    print_header "Installing paru"
    print_step "Installing base-devel..."
    sudo pacman -S --needed base-devel
    print_step "Cloning paru-git..."
    git clone https://aur.archlinux.org/paru-git.git /tmp/paru-git
    cd /tmp/paru-git
    makepkg -si
    cd "$SCRIPT_DIR"
    sudo rm -rf /tmp/paru-git
    print_success "paru installed"
}

install_awesome() {
    print_header "Installing awesome-git"
    sudo pacman -Rs awesome 2>/dev/null || true
    paru -S awesome-git
    print_success "awesome-git installed"
}

install_packages() {
    print_header "Installing all packages"
    paru -S \
        acpi alacritty alsa-utils ani-cli arandr aspell aspell-en autorandr \
        baobab bash-completion blueman bluez bluez-utils bulky \
        capitaine-cursors copyq cowsay cpupower-gui-git curl \
        dangerzone-bin discord docker docker-compose dracut \
        fastfetch fd firefox flameshot \
        gimp git github-cli glava gnome-disk-utility \
        highlight htop i3lock-color imgcat \
        jdk21-openjdk jdk8-openjdk keepassxc \
        lazygit less libconfig lobster-git localsend lolcat \
        man-db man-pages meld nano \
        nemo nemo-compare nemo-fileroller network-manager-applet nmap \
        noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra nvtop \
        pasystray pavucontrol pcloud-drive playerctl \
        plymouth plymouth-theme-hexagon-hud-git prismlauncher \
        qt6-svg ranger redshift rofi rofi-calc \
        ruby-fusuma ruby-fusuma-plugin-sendkey sof-firmware \
        spicetify-cli spotify-launcher steam tmux tree \
        unclutter unzip usbimager uthash \
        vim visual-studio-code-bin vlc vulkan-radeon vulkan-tools \
        wget xdotool xorg-xev xorg-xinput xorg-xset xss-lock zip
    # paru -S sunshine moonlight-qt
    # maybe this: lua54-lgi
    print_success "Packages installed"
}

install_autologin() {
    print_header "Configuring auto login"
    sudo systemctl edit getty@tty1.service --drop-in=autologin --stdin <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \u' --noclear --autologin victor %I %TERM
EOF
    print_success "Auto login configured for user: victor"
}

install_picom() {
    print_header "Building and installing picom"
    print_step "Cloning picom..."
    git clone https://github.com/pijulius/picom.git /tmp/picom
    cd /tmp/picom
    print_step "Building..."
    meson setup --buildtype=release build
    ninja -C build
    print_step "Installing..."
    sudo ninja -C build install
    cd "$SCRIPT_DIR"
    sudo rm -rf /tmp/picom
    print_success "picom installed"
}

install_amd_gpu() {
    print_header "Framework AMD GPU fix"
    local entry
    entry=$(ls /boot/loader/entries/ | head -1)
    sudo sed -i 's/^options .*/& amdgpu.dcdebugmask=0x10/' "/boot/loader/entries/${entry}"
    print_success "AMD GPU debug mask set in ${entry}"
}

install_plymouth() {
    print_header "Configuring Plymouth"
    local entry
    entry=$(ls /boot/loader/entries/ | head -1)
    print_step "Adding quiet splash to boot entry..."
    sudo sed -i 's/^options .*/& quiet splash/' "/boot/loader/entries/${entry}"
    print_step "Adding plymouth to mkinitcpio hooks..."
    sudo sed -i 's/HOOKS=(\([^)]*\)encrypt\([^)]*\))/HOOKS=(\1plymouth encrypt\2)/' /etc/mkinitcpio.conf
    print_step "Rebuilding initramfs..."
    sudo dracut
    print_step "Setting Plymouth theme..."
    sudo plymouth-set-default-theme -R hexagon_hud
    print_success "Plymouth configured"
}

install_power_button() {
    print_header "Configuring power button"
    sudo sed -i 's/#HandlePowerKey=poweroff/HandlePowerKey=ignore/' /etc/systemd/logind.conf
    print_success "Power button set to ignore"
}

install_bluetooth() {
    print_header "Enabling Bluetooth"
    systemctl enable bluetooth.service
    systemctl start bluetooth.service
    print_success "Bluetooth enabled and started"
}

install_touchpad() {
    print_header "Configuring touchpad"
    sudo sed -i '/Section "InputClass"/,/EndSection/ {
        /Identifier.*touchpad/,/EndSection/ {
        /Driver "libinput"/a\
        Option "Tapping" "on"\
        Option "NaturalScrolling" "true"\
        Option "ClickMethod" "clickfinger"
        }
}' /usr/share/X11/xorg.conf.d/40-libinput.conf
    print_success "Touchpad: tap-to-click, natural scroll, clickfinger enabled"
}

install_keyboard_layout() {
    print_header "Adding Bulgarian keyboard layout"
    sudo sed -i '/Section "InputClass"/,/EndSection/ {
        /Identifier.*system-keyboard/,/EndSection/ {
        s/Option "XkbLayout".*$/Option "XkbLayout" "us,bg"/
        /Option "XkbLayout"/a\
        Option "XkbVariant" ",bas_phonetic"
        }
}' /etc/X11/xorg.conf.d/00-keyboard.conf
    print_success "Bulgarian (bas_phonetic) layout added"
}

install_fusuma() {
    print_header "Setting up Fusuma (gestures)"
    sudo gpasswd -a "$USER" input
    mkdir -p "${HOME}/.config/fusuma"
    print_success "Fusuma configured — re-login required for group change"
}

install_ctrl_backspace() {
    print_header "Fixing Ctrl+Backspace in terminal"
    echo '"\C-H":"\C-W"' | sudo tee -a /etc/inputrc > /dev/null
    print_success "Ctrl+Backspace → Ctrl+W configured in /etc/inputrc"
}

install_monocraft() {
    print_header "Installing Monocraft Nerd Font"
    mkdir -p "${HOME}/.local/share/fonts"
    print_step "Downloading font..."
    curl -L -o "${HOME}/.local/share/fonts/Monocraft-nerd-fonts-patched.ttc" \
        https://github.com/IdreesInc/Monocraft/releases/download/v4.0/Monocraft-nerd-fonts-patched.ttc
    print_step "Refreshing font cache..."
    fc-cache
    fc-list | grep -i monocraft
    print_success "Monocraft font installed"
}

install_dns() {
    print_header "Setting static DNS (Cloudflare)"
    sudo tee /etc/NetworkManager/conf.d/dns-servers.conf > /dev/null <<'EOF'
[global-dns-domain-*]
servers=1.1.1.1,1.0.0.1
EOF
    print_success "Static DNS configured: 1.1.1.1, 1.0.0.1"
}

install_wireguard() {
    print_header "Setting up WireGuard VPN"
    read -e -p "  Enter path to WireGuard config file (FULL PATH): " wg_config_path
    local wg_config_name
    wg_config_name=$(basename "$wg_config_path" .conf)
    nmcli connection import type wireguard file "$wg_config_path"
    nmcli connection modify "$wg_config_name" connection.autoconnect no
    nmcli connection down "$wg_config_name" 2>/dev/null || true
    print_success "WireGuard VPN configured: ${wg_config_name}"
}

install_git_config() {
    print_header "Configuring Git"
    mkdir -p "${HOME}/Documents/GitHub"
    git config --global user.name "V1K1NGbg"
    git config --global user.email "victor@ilchev.com"
    # git config --global pull.rebase true
    print_success "Git global config set"
}

install_gh_auth() {
    print_header "GitHub CLI authentication"
    gh auth login
    print_success "GitHub CLI authenticated"
}

install_fingerprint() {
    print_header "Setting up fingerprint authentication"
    print_step "Enrolling fingerprint..."
    sudo fprintd-enroll "$USER"
    print_step "Adding to PAM (sudo)..."
    sudo sed -i '/#%PAM-1.0/a auth            sufficient      pam_fprintd.so' /etc/pam.d/sudo
    print_step "Adding to PAM (i3lock)..."
    sudo sed -i '/auth include system-local-login/i auth sufficient pam_unix.so try_first_pass likeauth nullok\nauth sufficient pam_fprintd.so timeout=10' /etc/pam.d/i3lock
    print_success "Fingerprint authentication configured"
}

install_ohmybash() {
    print_header "Installing oh-my-bash"
    # NOTE: the installer may start a new shell session — that is expected
    curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash
    print_success "oh-my-bash installed"
}

install_bashrc() {
    print_header "Configuring .bashrc"
    print_step "Removing source lines..."
    grep -v "source" "${HOME}/.bashrc" > /tmp/bashrc_tmp && mv -f /tmp/bashrc_tmp "${HOME}/.bashrc"
    print_step "Appending dots .bashrc..."
    cat "${SCRIPT_DIR}/.bashrc" >> "${HOME}/.bashrc"
    mark_done "bashrc"
    print_success ".bashrc configured"
}

install_nemo_config() {
    print_header "Configuring Nemo"
    dconf load /org/nemo/ < "${SCRIPT_DIR}/nemo_config"
    mark_done "nemo_config"
    print_success "Nemo configuration loaded"
}

install_dotfiles() {
    print_header "Copying dotfiles"
    print_step "Creating directories..."
    mkdir -p "${HOME}/.config/awesome/"
    mkdir -p "${HOME}/.config/alacritty/"
    mkdir -p "${HOME}/.vim/colors/"
    mkdir -p "${HOME}/Documents/BackUp/screenshots"
    mkdir -p "${HOME}/Documents/BackUp"
    mkdir -p "${HOME}/Documents/PC"

    print_step "Copying config directories..."
    yes | cp -rf "${SCRIPT_DIR}/.config/" ~
    yes | cp -rf "${SCRIPT_DIR}/.oh-my-bash/" ~ 2>/dev/null || true
    yes | cp -rf "${SCRIPT_DIR}/.vim/" ~
    yes | cp -rf "${SCRIPT_DIR}/.screenlayout/" ~ 2>/dev/null || true

    print_step "Copying dotfiles..."
    yes | cp -f \
        "${SCRIPT_DIR}/.bash_profile" \
        "${SCRIPT_DIR}/.tmux.conf" \
        "${SCRIPT_DIR}/.vimrc" \
        "${SCRIPT_DIR}/.Xresources" \
        "${SCRIPT_DIR}/i3lock.sh" ~

    mark_done "dotfiles"
    print_success "Dotfiles copied"
}

install_i3lock() {
    print_header "Setting up i3lock"
    chmod +x "${HOME}/i3lock.sh"
    print_success "i3lock.sh made executable"
}

install_default_apps() {
    print_header "Setting default applications"
    xdg-mime default xdg-open.desktop  *
    xdg-mime default code.desktop      text/*
    xdg-mime default firefox.desktop   text/html
    xdg-mime default firefox.desktop   application/pdf
    xdg-mime default vlc.desktop       video/*
    xdg-mime default vlc.desktop       audio/*
    xdg-mime default gimp.desktop      image/*
    xdg-mime default nemo.desktop      inode/*
    print_success "Default applications set"
}

install_nvm() {
    print_header "Installing nvm + Node.js"
    print_step "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    export NVM_DIR="${HOME}/.nvm"
    # shellcheck source=/dev/null
    [[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"
    print_step "Installing latest Node.js..."
    nvm install node
    print_success "nvm and Node.js installed"
}

install_vtop() {
    print_header "Installing vtop"
    npm install -g vtop
    print_success "vtop installed"
}

install_docker() {
    print_header "Setting up Docker"
    sudo systemctl enable docker.service
    sudo systemctl start docker.service
    sudo usermod -aG docker "$USER"
    print_success "Docker enabled — re-login required for group change"
}

install_pcloud() {
    print_header "Setting up pCloud"
    pcloud > /dev/null 2>&1 &
    read -p "  Log in pCloud and press Enter to continue..."
    read -p "  Sync ~/Documents/PC <-> pCloudDrive/PC, Backup ~/Documents/BackUp and press Enter to continue..."
    print_success "pCloud configured"
}

install_awesome_const() {
    print_header "Copying Awesome const file"
    read -e -p "  Awesome const path (FULL PATH): " awesome_const_path
    yes | cp -f "$awesome_const_path" "${HOME}/.config/awesome/"
    mark_done "awesome_const"
    print_success "Awesome const file copied"
}

install_discord() {
    print_header "Setting up Discord + BetterDiscord"
    discord > /dev/null 2>&1 &
    read -p "  Log in Discord and press Enter to continue..."
    xdg-open https://betterdiscord.app/ &
    read -p "  Download BetterDiscord installer and press Enter to continue..."
    chmod +x "${HOME}/Downloads/BetterDiscord-Linux.AppImage"
    "${HOME}/Downloads/BetterDiscord-Linux.AppImage" &
    read -p "  Set up BetterDiscord and press Enter to continue..."
    killall Discord 2>/dev/null || true
    mark_done "discord_setup"
    print_success "Discord + BetterDiscord configured"
}

install_spotify() {
    print_header "Setting up Spotify + Spicetify"
    spotify-launcher > /dev/null 2>&1 &
    read -p "  Log in Spotify, disable change song notification and press Enter to continue..."
    killall spotify-launcher 2>/dev/null || true
    print_step "Applying Spicetify theme..."
    spicetify backup apply
    spicetify config current_theme Ziro
    spicetify apply
    mark_done "spotify_setup"
    print_success "Spotify + Spicetify (Ziro theme) configured"
}

install_opencode() {
    print_header "Installing OpenCode"
    curl -fsSL https://opencode.ai/install | bash
    print_success "OpenCode installed"
}

install_vscode() {
    print_header "Setting up VSCode"
    code > /dev/null 2>&1 &
    read -p "  Log in VSCode, sync settings, WAIT FOR THE SYNC TO FINISH, and press Enter to continue..."
    killall code 2>/dev/null || true
    mark_done "vscode_setup"
    print_success "VSCode configured"
}

install_copyq() {
    print_header "Setting up CopyQ"
    copyq &
    read -p "  Import CopyQ config, set shortcut for WINDOW UNDER MOUSE and press Enter to continue..."
    killall copyq 2>/dev/null || true
    mark_done "copyq_setup"
    print_success "CopyQ configured"
}

install_firefox() {
    print_header "Setting up Firefox"
    firefox > /dev/null 2>&1 &
    read -p "  Log in Firefox
  Sync settings
  Import vimium and bonjourr configs
  Fix persistant tabs
  Fix bookmarks layout
  Set duck duck go as default search engine
  Add cookies exceptions (google,github,uni, netflix)
  and finally press Enter to continue..."
    killall firefox 2>/dev/null || true
    mark_done "firefox_setup"
    print_success "Firefox configured"
}

install_steam() {
    print_header "Setting up Steam"
    steam > /dev/null 2>&1 &
    read -p "  Log in Steam and press Enter to continue... (WARNING: takes a while!)"
    killall steam 2>/dev/null || true
    mark_done "steam_setup"
    print_success "Steam configured"
}

install_docker_containers() {
    print_header "Starting Docker containers"
    cd "$SCRIPT_DIR"
    docker-compose up -d
    print_success "Docker containers started"
    echo -e "  ${DIM}To pull Ollama models:${NC}"
    echo -e "  ${DIM}  curl http://localhost:11434/api/pull -d '{\"model\": \"qwen3:8b\"}'${NC}"
}

# ==============================================================================
# TASK REGISTRY
# ==============================================================================

TASK_NAMES=(
    "Enable multilib"
    "Update system"
    "Install paru"
    "Install awesome-git"
    "Install all packages"
    "Configure auto login"
    "Build & install picom"
    "AMD GPU fix (Framework)"
    "Configure Plymouth"
    "Configure power button"
    "Enable Bluetooth"
    "Configure touchpad"
    "Add Bulgarian keyboard layout"
    "Set up Fusuma (gestures)"
    "Fix Ctrl+Backspace in terminal"
    "Install Monocraft font"
    "Set static DNS"
    "Configure Git"
    "Authenticate GitHub CLI"
    "Set up fingerprint auth"
    "Install oh-my-bash"
    "Configure .bashrc"
    "Configure Nemo"
    "Copy dotfiles"
    "Set up i3lock"
    "Set default applications"
    "Install nvm + Node.js"
    "Install vtop"
    "Set up Docker"
    "Set up pCloud"
    "Configure WireGuard VPN"
    "Copy awesome const file"
    "Set up Discord + BetterDiscord"
    "Set up Spotify + Spicetify"
    "Install OpenCode"
    "Set up VSCode"
    "Set up CopyQ"
    "Set up Firefox"
    "Set up Steam"
    "Start Docker containers"
)

TASK_CHECKS=(
    check_multilib
    check_system_updated
    check_paru
    check_awesome
    check_packages
    check_autologin
    check_picom
    check_amd_gpu
    check_plymouth
    check_power_button
    check_bluetooth
    check_touchpad
    check_keyboard_layout
    check_fusuma
    check_ctrl_backspace
    check_monocraft
    check_dns
    check_git_config
    check_gh_auth
    check_fingerprint
    check_ohmybash
    check_bashrc
    check_nemo_config
    check_dotfiles
    check_i3lock
    check_default_apps
    check_nvm
    check_vtop
    check_docker
    check_pcloud
    check_wireguard
    check_awesome_const
    check_discord
    check_spotify
    check_opencode
    check_vscode
    check_copyq
    check_firefox
    check_steam
    check_docker_containers
)

TASK_INSTALLS=(
    install_multilib
    install_system_update
    install_paru
    install_awesome
    install_packages
    install_autologin
    install_picom
    install_amd_gpu
    install_plymouth
    install_power_button
    install_bluetooth
    install_touchpad
    install_keyboard_layout
    install_fusuma
    install_ctrl_backspace
    install_monocraft
    install_dns
    install_git_config
    install_gh_auth
    install_fingerprint
    install_ohmybash
    install_bashrc
    install_nemo_config
    install_dotfiles
    install_i3lock
    install_default_apps
    install_nvm
    install_vtop
    install_docker
    install_pcloud
    install_wireguard
    install_awesome_const
    install_discord
    install_spotify
    install_opencode
    install_vscode
    install_copyq
    install_firefox
    install_steam
    install_docker_containers
)

TASK_COUNT=${#TASK_NAMES[@]}

declare -a TASK_STATUS    # 0 = done, 1 = todo
declare -a TASK_SELECTED  # 0 = unselected, 1 = selected

# ==============================================================================
# TUI
# ==============================================================================

TUI_CURSOR=0
TUI_SCROLL=0
TUI_VISIBLE_ROWS=15
TUI_LAST_MSG=""

refresh_status() {
    local label="${1:-Checking installation status}"
    for (( i=0; i<TASK_COUNT; i++ )); do
        echo -ne "\r${CYAN}${label}${NC} [${i}/${TASK_COUNT}]  "
        if "${TASK_CHECKS[$i]}" 2>/dev/null; then
            TASK_STATUS[$i]=0
        else
            TASK_STATUS[$i]=1
        fi
    done
    echo -ne "\r\033[K"  # clear line
}

draw_tui() {
    local term_rows
    term_rows=$(tput lines 2>/dev/null || echo 24)
    TUI_VISIBLE_ROWS=$(( term_rows - 9 ))
    (( TUI_VISIBLE_ROWS < 5 )) && TUI_VISIBLE_ROWS=5

    local done_count=0 selected_count=0
    for (( i=0; i<TASK_COUNT; i++ )); do
        (( TASK_STATUS[i]   == 0 )) && (( done_count++ ))     || true
        (( TASK_SELECTED[i] == 1 )) && (( selected_count++ )) || true
    done

    tput clear

    # Header
    echo -e "${BOLD}${CYAN}${SEP}${NC}"
    echo -e "${BOLD}${CYAN}  ARCH LINUX INSTALLER${NC}"
    echo -e "${BOLD}${CYAN}${SEP}${NC}"
    printf "  Progress: ${GREEN}%d${NC}/%d done  │  Selected: ${YELLOW}%d${NC} tasks\n" \
        "$done_count" "$TASK_COUNT" "$selected_count"
    echo -e "${DIM}${DIV}${NC}"

    # Task list
    local end=$(( TUI_SCROLL + TUI_VISIBLE_ROWS - 1 ))
    (( end >= TASK_COUNT )) && end=$(( TASK_COUNT - 1 ))

    for (( i=TUI_SCROLL; i<=end; i++ )); do
        local name="${TASK_NAMES[$i]}"
        (( ${#name} > 38 )) && name="${name:0:35}..."
        local padded
        padded=$(printf "%-38s" "$name")

        local sel_sym status_sym

        if (( TASK_SELECTED[i] == 1 )); then
            sel_sym="${YELLOW}●${NC}"
        else
            sel_sym="${DIM}○${NC}"
        fi

        if (( TASK_STATUS[i] == 0 )); then
            status_sym="${GREEN}✓ done${NC}"
        else
            status_sym="${RED}✗ todo${NC}"
        fi

        if (( i == TUI_CURSOR )); then
            echo -e "${CYAN}▶ ${NC}[${sel_sym}] ${BOLD}${padded}${NC}  ${status_sym}"
        else
            echo -e "  [${sel_sym}] ${padded}  ${status_sym}"
        fi
    done

    # Scroll hint
    if (( TASK_COUNT > TUI_VISIBLE_ROWS )); then
        echo -e "${DIM}  showing $(( TUI_SCROLL + 1 ))–$(( end + 1 )) of ${TASK_COUNT}${NC}"
    fi

    # Footer
    echo -e "${DIM}${DIV}${NC}"
    if [[ -n "$TUI_LAST_MSG" ]]; then
        echo -e "  ${TUI_LAST_MSG}"
    else
        echo -e "  ${CYAN}↑↓${NC} navigate  ${CYAN}SPACE${NC} toggle  ${CYAN}A${NC} all  ${CYAN}N${NC} none  ${CYAN}U${NC} unfinished"
    fi
    echo -e "  ${GREEN}ENTER${NC} run selected  ${CYAN}R${NC} refresh  ${RED}Q${NC} quit"
    echo -e "${BOLD}${CYAN}${SEP}${NC}"
}

run_tui() {
    for (( i=0; i<TASK_COUNT; i++ )); do
        TASK_SELECTED[$i]=0
        TASK_STATUS[$i]=1
    done

    refresh_status

    trap 'tput cnorm; tput clear' EXIT

    tput civis  # hide cursor

    while true; do
        TUI_LAST_MSG=""
        draw_tui

        # Read key input
        local key seq1 seq2
        IFS= read -rsn1 key

        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn1 -t 0.1 seq1
            IFS= read -rsn1 -t 0.1 seq2
            if [[ "$seq1" == '[' ]]; then
                case "$seq2" in
                    'A')  # Up arrow
                        (( TUI_CURSOR > 0 )) && (( TUI_CURSOR-- )) || true
                        (( TUI_CURSOR < TUI_SCROLL )) && (( TUI_SCROLL-- )) || true
                        ;;
                    'B')  # Down arrow
                        (( TUI_CURSOR < TASK_COUNT - 1 )) && (( TUI_CURSOR++ )) || true
                        (( TUI_CURSOR >= TUI_SCROLL + TUI_VISIBLE_ROWS )) && (( TUI_SCROLL++ )) || true
                        ;;
                    '5')  # Page Up
                        IFS= read -rsn1 -t 0.1  # consume trailing ~
                        (( TUI_CURSOR -= TUI_VISIBLE_ROWS ))
                        (( TUI_CURSOR < 0 )) && TUI_CURSOR=0 || true
                        (( TUI_CURSOR < TUI_SCROLL )) && TUI_SCROLL=$TUI_CURSOR || true
                        ;;
                    '6')  # Page Down
                        IFS= read -rsn1 -t 0.1  # consume trailing ~
                        (( TUI_CURSOR += TUI_VISIBLE_ROWS ))
                        (( TUI_CURSOR >= TASK_COUNT )) && TUI_CURSOR=$(( TASK_COUNT - 1 )) || true
                        (( TUI_CURSOR >= TUI_SCROLL + TUI_VISIBLE_ROWS )) && \
                            TUI_SCROLL=$(( TUI_CURSOR - TUI_VISIBLE_ROWS + 1 )) || true
                        ;;
                esac
            fi

        elif [[ "$key" == ' ' ]]; then
            if (( TASK_SELECTED[TUI_CURSOR] == 1 )); then
                TASK_SELECTED[$TUI_CURSOR]=0
            else
                TASK_SELECTED[$TUI_CURSOR]=1
            fi

        elif [[ "${key,,}" == 'a' ]]; then
            for (( i=0; i<TASK_COUNT; i++ )); do TASK_SELECTED[$i]=1; done

        elif [[ "${key,,}" == 'n' ]]; then
            for (( i=0; i<TASK_COUNT; i++ )); do TASK_SELECTED[$i]=0; done

        elif [[ "${key,,}" == 'u' ]]; then
            # Select all unfinished tasks
            local cnt=0
            for (( i=0; i<TASK_COUNT; i++ )); do
                if (( TASK_STATUS[i] == 1 )); then
                    TASK_SELECTED[$i]=1
                    (( cnt++ ))
                else
                    TASK_SELECTED[$i]=0
                fi
            done
            TUI_LAST_MSG="${YELLOW}Selected ${cnt} unfinished tasks${NC}"

        elif [[ "${key,,}" == 'r' ]]; then
            tput cnorm
            tput clear
            refresh_status "Refreshing"
            tput civis

        elif [[ "${key,,}" == 'q' ]]; then
            tput cnorm
            tput clear
            echo -e "${YELLOW}Installer exited.${NC}"
            exit 0

        elif [[ -z "$key" ]]; then
            # Enter — run selected tasks
            local any_selected=0
            for (( i=0; i<TASK_COUNT; i++ )); do
                (( TASK_SELECTED[i] == 1 )) && any_selected=1 && break
            done

            if (( any_selected == 0 )); then
                TUI_LAST_MSG="${YELLOW}No tasks selected — use SPACE to toggle${NC}"
                continue
            fi

            tput cnorm
            tput clear

            local failed=()
            echo -e "${BOLD}${GREEN}Running selected tasks...${NC}\n"

            for (( i=0; i<TASK_COUNT; i++ )); do
                if (( TASK_SELECTED[i] == 1 )); then
                    echo -e "${BOLD}${BLUE}[$(( i + 1 ))/${TASK_COUNT}] ${TASK_NAMES[$i]}${NC}"
                    if "${TASK_INSTALLS[$i]}"; then
                        TASK_STATUS[$i]=0
                    else
                        print_error "Task failed: ${TASK_NAMES[$i]}"
                        failed+=("${TASK_NAMES[$i]}")
                    fi
                    TASK_SELECTED[$i]=0
                fi
            done

            echo
            if (( ${#failed[@]} > 0 )); then
                echo -e "${RED}${BOLD}The following tasks failed:${NC}"
                for t in "${failed[@]}"; do echo -e "  ${RED}✗${NC} ${t}"; done
            else
                echo -e "${GREEN}${BOLD}All selected tasks completed successfully!${NC}"
            fi
            read -rp "Press Enter to return to the menu..."

            refresh_status "Refreshing"
            tput civis
        fi
    done
}

# ==============================================================================
# ENTRY POINT
# ==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tui
fi

# ==============================================================================
# REFERENCE (not executed)
# ==============================================================================

# !!! ONLY FOR NVIDIA GPU'S (NOT SUPPORTED) !!!
# # install nvidia drivers (https://wiki.archlinux.org/title/NVIDIA)
# paru -S nvidia-open nvidia-utils nvidia-settings
# # install requirements for gpu enabling/disabling gpu
# paru -S envycontrol
# # change to integrated
# sudo envycontrol -s integrated

# # cursor !OLD!
# vim .Xresources
# #Xcursor.theme: capitaine-cursors
# #Xcursor.size: 24
# # RESTART XORG

# # gtk !OLD!
# vim ~/.config/gtk-3.0/settings.ini
# #gtk-application-prefer-dark-theme=1

# # feh !OLD!
# feh --bg-scale ${imageurl}

# # fix monitor setup !OLD!
# # arandr to setup ONLY LAPTOP
# autorandr --save laptop
# autorandr --default laptop
# # arandr to setup EXTEND LAPTOP
# autorandr --save laptop_external
# # # arandr to setup DUPLICATE LAPTOP
# # autorandr --save laptop_duplicate

# # generate ranger config !OLD!
# ranger --copy-config=all
# vim .config/ranger/rc.conf
# # set show_hidden true
# # set colorscheme jungle

# # copy gnome-terminal !OLD!
# # export
# dconf dump /org/gnome/terminal/ > gnome_terminal_settings.txt
# #copy contents (https://gist.github.com/V1K1NGbg/28d6098e4013ca7b904453cf96c671cd)
# #import
# dconf load /org/gnome/terminal/ < gnome_terminal_settings.txt
# rm gnome_terminal_settings.txt

# # install fzf-tab-completion !OLD!
# # git clone https://github.com/lincheney/fzf-tab-completion

# # download custom commands !OLD!
# # lastline
# git clone https://gist.github.com/V1K1NGbg/50f618cf392ad0ea85f398e1ca5fe24f a && sudo chmod +x a/lastline && sudo mv a/* /usr/bin && rm -rf a

# # docker old setup !OLD!
# cd dots
# mkdir ~/docker_data/pihole/etc-pihole
# mkdir ~/docker_data/pihole/etc-dnsmasq.d
# mkdir ~/docker_data/portainer
# ./docker_setup.sh

# # cloudflare-warp !OLD!
# sudo systemctl enable warp-svc
# sudo systemctl start warp-svc
# warp-cli registration new

# Useful commands:
#   paru -Qqen > pkglist.txt               # list installed packages
#   xrandr --output eDP-1 --brightness 0.5 # change brightness
#   redshift -P -O 4500 / redshift -x      # color temperature
#   gpg --keyserver-options auto-key-retrieve --verify archlinux.iso.sig
#
# Ollama model pull examples (after docker containers are running):
#   curl http://localhost:11434/api/pull -d '{"model": "qwen3:8b"}'
#   curl http://localhost:11434/api/pull -d '{"model": "qwen3:14b"}'
#   curl http://localhost:11434/api/pull -d '{"model": "qwen3:32b"}'

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

# A fresh shell keeps errexit active even though the TUI tests its exit status.
# Calling a shell function directly in `if` would disable errexit in that function.
run_task() {
    bash -e -o pipefail "$SCRIPT_DIR/install.sh" --run-task "$1"
}

rebuild_initramfs() {
    local kernel_cmdline

    kernel_cmdline=$(sudo cat /etc/kernel/cmdline) || return
    kernel_cmdline=${kernel_cmdline//$'\n'/ }
    kernel_cmdline=${kernel_cmdline% }
    if [[ ! "$kernel_cmdline" =~ [^[:space:]] ]]; then
        print_error "Refusing to rebuild with an empty /etc/kernel/cmdline"
        return 1
    fi
    sudo install -d -m 0755 /etc/dracut.conf.d
    # dracut sources this as shell code; quote literal command-line characters.
    printf 'kernel_cmdline=%q\n' "$kernel_cmdline" \
        | sudo tee /etc/dracut.conf.d/20-cmdline.conf > /dev/null
    sudo dracut --regenerate-all --force
}

# Full package set for the graphical installation stage.
readonly -a REPO_PACKAGES=(
    acpi adw-gtk-theme alacritty alsa-utils aspell aspell-en
    baobab bash-completion blueman bluez bluez-utils brightnessctl bulky
    capitaine-cursors
    cliphist clang cowsay curl dconf discord docker docker-compose dracut
    fastfetch fd firefox fprintd gimp git github-cli gnome-disk-utility
    go gopls grim highlight htop hypridle hyprland hyprlock hyprpolkitagent hyprsunset
    jdk21-openjdk jdk8-openjdk keepassxc lazygit less libinput
    libnotify libqalculate llama-cpp ggml-vulkan lolcat mako
    man-db man-pages meld nano nemo nemo-fileroller networkmanager network-manager-applet nmap
    noto-fonts noto-fonts-cjk noto-fonts-emoji nvtop nwg-displays nwg-look
    papirus-icon-theme pavucontrol pipewire pipewire-alsa
    pipewire-pulse playerctl plymouth
    poppler power-profiles-daemon prettier
    prismlauncher pyright python python-black qt5ct qt6ct
    ranger rofi rofi-calc rust rust-analyzer slurp sof-firmware spotify-launcher steam
    swappy tmux tree typescript-language-server unzip vim
    code vlc vulkan-radeon lib32-vulkan-radeon vulkan-tools
    waybar wev wget wireplumber wl-clipboard xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland xdg-utils zip uwsm
)

readonly -a AUR_PACKAGES=(
    ani-cli
    imgcat
    localsend
    pcloud-drive
    plymouth-theme-hexagon-hud-git
    usbimager
)

readonly -a PACKAGES=("${REPO_PACKAGES[@]}" "${AUR_PACKAGES[@]}")

# ==============================================================================
# CHECK FUNCTIONS  (return 0 = done, non-zero = not done)
# ==============================================================================

check_multilib()          { grep -q '^\[multilib\]' /etc/pacman.conf; }
check_system_updated()    { is_marked "system_updated"; }
check_paru()              { cmd_exists paru; }
check_packages()          { pacman -Qq "${PACKAGES[@]}" &>/dev/null; }
check_amd_gpu()           { is_marked amd_gpu && grep -q 'amdgpu.dcdebugmask' /etc/kernel/cmdline 2>/dev/null; }
check_plymouth()          { is_marked plymouth && grep -q 'splash' /etc/kernel/cmdline 2>/dev/null && [[ -f /etc/dracut.conf.d/plymouth.conf ]]; }
check_power_button()      { grep -q '^HandlePowerKey=ignore' /etc/systemd/logind.conf; }
check_bluetooth()         { systemctl is-enabled bluetooth.service &>/dev/null; }
check_desktop_services()  { systemctl is-enabled power-profiles-daemon.service &>/dev/null; }
check_ctrl_backspace()    { grep -qF '"\C-H"' /etc/inputrc 2>/dev/null; }
check_monocraft()         { fc-list 2>/dev/null | grep -qi monocraft; }
check_dns()               { grep -q '1.1.1.1' /etc/NetworkManager/conf.d/dns-servers.conf 2>/dev/null; }
check_wireguard()         { nmcli connection show 2>/dev/null | grep -qi wireguard; }
check_git_config()        { [[ -n "$(git config --global user.name 2>/dev/null)" ]]; }
check_gh_auth()           { gh auth status &>/dev/null; }
check_fingerprint()       { grep -q 'pam_fprintd' /etc/pam.d/sudo 2>/dev/null && grep -q 'pam_fprintd' /etc/pam.d/hyprlock 2>/dev/null && fprintd-list "$USER" 2>/dev/null | grep -q 'right-index-finger'; }
check_ohmybash()          { [[ -f "${HOME}/.oh-my-bash/oh-my-bash.sh" ]]; }
check_bashrc()            { cmp -s "${SCRIPT_DIR}/.bashrc" "${HOME}/.bashrc"; }
check_nemo_config()       { dconf read /org/nemo/preferences/bulk-rename-tool 2>/dev/null | grep -q 'bulky'; }
check_dotfiles()          { [[ -f "${HOME}/.vimrc" && -f "${HOME}/.tmux.conf" && -f "${HOME}/.bash_profile" && -f "${HOME}/.config/hypr/hyprland.lua" && -f "${HOME}/.config/waybar/config.jsonc" && -d "${HOME}/.config/alacritty" ]]; }
check_default_apps()      { xdg-mime query default text/html 2>/dev/null | grep -q firefox; }
check_nvm()               { [[ -d "${HOME}/.nvm" ]]; }
check_vtop()              { cmd_exists vtop; }
check_docker()            { systemctl is-enabled docker.service &>/dev/null; }
check_pcloud()            { cmd_exists pcloud; }
check_discord()           { [[ -d "${HOME}/.config/BetterDiscord" ]]; }
check_spotify()           { is_marked "spotify_setup"; }
check_opencode()          { is_marked "opencode_setup"; }
check_vscode()            { is_marked "vscode_setup"; }
check_firefox()           { is_marked "firefox_setup"; }
check_steam()             { is_marked "steam_setup"; }
check_llama_cpp()         { systemctl --user is-enabled llama-cpp.service &>/dev/null; }

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

install_paru() (
    print_header "Installing paru"
    local build_dir
    print_step "Installing base-devel..."
    sudo pacman -S --needed base-devel
    print_step "Cloning paru-git..."
    build_dir=$(mktemp -d /tmp/dots-paru.XXXXXX)
    trap 'rm -rf -- "$build_dir"' EXIT
    git clone https://aur.archlinux.org/paru-git.git "$build_dir"
    cd "$build_dir"
    makepkg -si
    print_success "paru installed"
)

install_packages() {
    print_header "Installing repository packages"
    sudo pacman -S --needed "${REPO_PACKAGES[@]}"
    print_header "Installing AUR-only packages"
    paru -S --needed "${AUR_PACKAGES[@]}"
    print_success "Packages installed"
}

install_amd_gpu() {
    print_header "Framework AMD GPU fix"
    print_step "Adding amdgpu.dcdebugmask=0x10 to kernel cmdline..."
    grep -q 'amdgpu.dcdebugmask' /etc/kernel/cmdline 2>/dev/null \
        || sudo sed -i '1s/$/ amdgpu.dcdebugmask=0x10/' /etc/kernel/cmdline
    [[ -f /etc/kernel/cmdline && $(wc -l < /etc/kernel/cmdline) -gt 1 ]] \
        && sudo sed -i ':a;N;$!ba;s/\n/ /g' /etc/kernel/cmdline
    print_step "Rebuilding UKI..."
    rebuild_initramfs
    mark_done amd_gpu
    print_success "AMD GPU debug mask set"
}

install_plymouth() {
    print_header "Configuring Plymouth"
    print_step "Adding quiet splash to kernel cmdline..."
    grep -q 'quiet splash' /etc/kernel/cmdline 2>/dev/null \
        || sudo sed -i '1s/$/ quiet splash/' /etc/kernel/cmdline
    [[ -f /etc/kernel/cmdline && $(wc -l < /etc/kernel/cmdline) -gt 1 ]] \
        && sudo sed -i ':a;N;$!ba;s/\n/ /g' /etc/kernel/cmdline
    print_step "Configuring dracut for Plymouth..."
    echo 'add_dracutmodules+=" plymouth "' | sudo tee /etc/dracut.conf.d/plymouth.conf > /dev/null
    print_step "Setting Plymouth theme..."
    sudo plymouth-set-default-theme hexagon_hud
    print_step "Rebuilding UKI..."
    rebuild_initramfs
    mark_done plymouth
    print_success "Plymouth configured"
}

install_power_button() {
    print_header "Configuring power button"
    sudo sed -i 's/#HandlePowerKey=poweroff/HandlePowerKey=ignore/' /etc/systemd/logind.conf
    print_success "Power button set to ignore"
}

install_bluetooth() {
    print_header "Enabling Bluetooth"
    sudo systemctl enable --now bluetooth.service
    print_success "Bluetooth enabled and started"
}

install_desktop_services() {
    print_header "Enabling Hyprland desktop service"
    sudo systemctl enable --now power-profiles-daemon.service
    print_success "Power profiles enabled"
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
    curl -fL -o "${HOME}/.local/share/fonts/Monocraft-nerd-fonts-patched.ttc" \
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
    print_step "Adding fingerprint authentication to PAM..."
    grep -q 'pam_fprintd' /etc/pam.d/sudo 2>/dev/null \
        || sudo sed -i '/#%PAM-1.0/a auth            sufficient      pam_fprintd.so' /etc/pam.d/sudo
    grep -q 'pam_fprintd' /etc/pam.d/hyprlock 2>/dev/null \
        || sudo sed -i '1a auth            sufficient      pam_fprintd.so' /etc/pam.d/hyprlock
    print_success "Fingerprint authentication configured"
}

install_ohmybash() {
    print_header "Installing oh-my-bash"
    curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended
    # Upstream replaces .bashrc, even if the TUI had marked it done.
    install_bashrc
    print_success "oh-my-bash installed"
}

install_bashrc() {
    print_header "Configuring .bashrc"
    local backup replacement
    bash -n "${SCRIPT_DIR}/.bashrc"
    if ! cmp -s "${SCRIPT_DIR}/.bashrc" "${HOME}/.bashrc"; then
        if [[ -e "${HOME}/.bashrc" || -L "${HOME}/.bashrc" ]]; then
            backup=$(mktemp "${HOME}/.bashrc.backup.XXXXXX")
            cp -p "${HOME}/.bashrc" "$backup"
            print_step "Saved previous .bashrc to $backup"
        fi
        replacement=$(mktemp "${HOME}/.bashrc.install.XXXXXX")
        install -m 0644 "${SCRIPT_DIR}/.bashrc" "$replacement"
        mv -f "$replacement" "${HOME}/.bashrc"
    fi
    print_success ".bashrc configured"
}

install_nemo_config() {
    print_header "Configuring Nemo"
    dconf load /org/nemo/ < "${SCRIPT_DIR}/nemo_config"
    print_success "Nemo configuration loaded"
}

install_dotfiles() {
    print_header "Copying dotfiles"
    print_step "Creating directories..."
    mkdir -p "${HOME}/.config"
    mkdir -p "${HOME}/Documents/BackUp/screenshots"
    mkdir -p "${HOME}/Documents/PC"

    print_step "Copying config directories..."
    local config_dir
    for config_dir in \
        BetterDiscord alacritty gtk-3.0 gtk-4.0 hypr keepassxc mako \
        opencode qt5ct qt6ct rofi systemd uwsm waybar; do
        cp -rf "${SCRIPT_DIR}/.config/${config_dir}" "${HOME}/.config/"
    done
    cp -rf "${SCRIPT_DIR}/.oh-my-bash/" "$HOME/"
    cp -rf "${SCRIPT_DIR}/.vim/" "$HOME/"

    print_step "Copying dotfiles..."
    cp -f \
        "${SCRIPT_DIR}/.bash_profile" \
        "${SCRIPT_DIR}/.tmux.conf" \
        "${SCRIPT_DIR}/.vimrc" ~

    print_success "Dotfiles copied"
}

install_default_apps() {
    print_header "Setting default applications"
    xdg-mime default code.desktop      text/plain
    xdg-mime default firefox.desktop   text/html
    xdg-mime default firefox.desktop   x-scheme-handler/http
    xdg-mime default firefox.desktop   x-scheme-handler/https
    xdg-mime default firefox.desktop   application/pdf
    xdg-mime default vlc.desktop       video/mp4 video/x-matroska
    xdg-mime default vlc.desktop       audio/mpeg audio/flac
    xdg-mime default gimp.desktop      image/png image/jpeg
    xdg-mime default nemo.desktop      inode/directory
    print_success "Default applications set"
}

install_nvm() {
    print_header "Installing nvm + Node.js"
    print_step "Installing nvm..."
    curl -fL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    export NVM_DIR="${HOME}/.nvm"
    # shellcheck source=/dev/null
    [[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"
    print_step "Installing latest Node.js..."
    nvm install node
    print_success "nvm and Node.js installed"
}

install_vtop() {
    print_header "Installing vtop"
    export NVM_DIR="${HOME}/.nvm"
    # shellcheck source=/dev/null
    [[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"
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
    read -p "  Enable start up minimised, Sync ~/Documents/PC <-> pCloudDrive/PC, Backup ~/Documents/BackUp and press Enter to continue..."
    print_success "pCloud configured"
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
    print_success "Discord + BetterDiscord configured"
}

install_spotify() {
    print_header "Setting up Spotify"
    spotify-launcher > /dev/null 2>&1 &
    read -p "  Log in Spotify, disable change song notification and press Enter to continue..."
    killall spotify-launcher 2>/dev/null || true
    mark_done "spotify_setup"
    print_success "Spotify configured"
}

install_opencode() {
    print_header "Installing OpenCode"
    curl -fsSL https://opencode.ai/install | bash
    mark_done "opencode_setup"
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

install_llama_cpp() {
    print_header "Starting llama.cpp service"
    mkdir -p "${HOME}/.config/systemd/user"
    cp -f "${SCRIPT_DIR}/.config/systemd/user/llama-cpp.service" \
        "${HOME}/.config/systemd/user/"
    systemctl --user daemon-reload
    systemctl --user enable --now llama-cpp.service
    print_success "llama.cpp enabled; the model downloads automatically on first start"
}

# ==============================================================================
# TASK REGISTRY
# ==============================================================================

TASK_NAMES=(
    "Enable multilib"
    "Update system"
    "Install paru"
    "Install all packages"
    "AMD GPU fix (Framework)"
    "Configure Plymouth"
    "Configure power button"
    "Enable Bluetooth"
    "Enable Hyprland desktop service"
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
    "Set default applications"
    "Install nvm + Node.js"
    "Install vtop"
    "Set up Docker"
    "Set up pCloud"
    "Configure WireGuard VPN"
    "Set up Discord + BetterDiscord"
    "Set up Spotify"
    "Install OpenCode"
    "Set up VSCode"
    "Set up Firefox"
    "Set up Steam"
    "Start llama.cpp service"
)

TASK_CHECKS=(
    check_multilib
    check_system_updated
    check_paru
    check_packages
    check_amd_gpu
    check_plymouth
    check_power_button
    check_bluetooth
    check_desktop_services
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
    check_default_apps
    check_nvm
    check_vtop
    check_docker
    check_pcloud
    check_wireguard
    check_discord
    check_spotify
    check_opencode
    check_vscode
    check_firefox
    check_steam
    check_llama_cpp
)

TASK_INSTALLS=(
    install_multilib
    install_system_update
    install_paru
    install_packages
    install_amd_gpu
    install_plymouth
    install_power_button
    install_bluetooth
    install_desktop_services
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
    install_default_apps
    install_nvm
    install_vtop
    install_docker
    install_pcloud
    install_wireguard
    install_discord
    install_spotify
    install_opencode
    install_vscode
    install_firefox
    install_steam
    install_llama_cpp
)

TASK_COUNT=${#TASK_NAMES[@]}

if (( TASK_COUNT != ${#TASK_CHECKS[@]} )) || (( TASK_COUNT != ${#TASK_INSTALLS[@]} )); then
    print_error "Task registry arrays have different lengths"
    exit 1
fi

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

            local failed=0
            echo -e "${BOLD}${GREEN}Running selected tasks...${NC}\n"

            for (( i=0; i<TASK_COUNT; i++ )); do
                if (( TASK_SELECTED[i] == 1 )); then
                    echo -e "${BOLD}${BLUE}[$(( i + 1 ))/${TASK_COUNT}] ${TASK_NAMES[$i]}${NC}"
                    if run_task "${TASK_INSTALLS[$i]}"; then
                        TASK_STATUS[$i]=0
                    else
                        TASK_STATUS[$i]=1
                        print_error "Task failed: ${TASK_NAMES[$i]}"
                        failed=1
                        print_error "Remaining tasks were not run. Resolve the failure before continuing."
                        break
                    fi
                    TASK_SELECTED[$i]=0
                fi
            done

            echo
            if (( failed == 0 )); then
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
    if [[ ${1:-} == --run-task ]]; then
        # Only registered tasks can be dispatched, including when invoked directly.
        for task in "${TASK_INSTALLS[@]}"; do
            if [[ "$task" == "${2:-}" && $# -eq 2 ]]; then
                set -e -o pipefail
                "$task"
                exit 0
            fi
        done
        print_error "Unknown installation task"
        exit 1
    elif (( $# > 0 )); then
        print_error "Usage: ./install.sh"
        exit 1
    else
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

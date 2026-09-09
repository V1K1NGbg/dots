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
    fastfetch fd firefox fprintd fzf gimp git github-cli gnome-disk-utility
    go gopls grim highlight htop hypridle hyprland hyprlock hyprpolkitagent hyprsunset
    jdk21-openjdk jdk17-openjdk jdk8-openjdk keepassxc lazygit less libinput
    libnotify libpulse libqalculate llama-cpp ggml-vulkan lolcat mako
    man-db man-pages meld nano nemo nemo-fileroller networkmanager network-manager-applet nmap
    noto-fonts noto-fonts-cjk noto-fonts-emoji nvtop nwg-displays nwg-look
    papirus-icon-theme pavucontrol pipewire pipewire-alsa
    pipewire-pulse playerctl plymouth
    poppler power-profiles-daemon prettier
    prismlauncher pyright python python-black jq qt5ct qt6ct
    ranger rofi rofi-calc rust rust-analyzer slurp sof-firmware spotify-launcher steam
    swappy tmux tree typescript-language-server unzip vim
    code vlc vulkan-radeon lib32-vulkan-radeon vulkan-tools
    waybar wev wget wireplumber wl-clipboard xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland xdg-utils zip uwsm
)

readonly -a AUR_PACKAGES=(
    ani-cli
    rofi-blocks-git
    imgcat
    localsend
    opencode
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
check_plymouth()          { is_marked plymouth && grep -q 'splash' /etc/kernel/cmdline 2>/dev/null && [[ -f /etc/dracut.conf.d/plymouth.conf && -f /etc/dracut.conf.d/30-monocraft.conf ]]; }
check_power_button()      { grep -q '^HandlePowerKey=ignore' /etc/systemd/logind.conf; }
check_bluetooth()         { systemctl is-enabled bluetooth.service &>/dev/null; }
check_desktop_services()  { systemctl is-enabled power-profiles-daemon.service &>/dev/null; }
check_ctrl_backspace()    { grep -qF '"\C-H"' /etc/inputrc 2>/dev/null; }
check_monocraft()         { fc-list 2>/dev/null | grep -qi monocraft && [[ -f ${HOME}/.config/fontconfig/conf.d/99-monocraft.conf ]]; }
check_system_fonts() {
    check_monocraft && [[ -f /etc/dracut.conf.d/30-monocraft.conf ]] &&
        grep -q '^Theme=hexagon_hud_monocraft$' /etc/plymouth/plymouthd.conf &&
        grep -q '^FONT=monocraft$' /etc/vconsole.conf
}

check_dns()               { grep -q '1.1.1.1' /etc/NetworkManager/conf.d/dns-servers.conf 2>/dev/null; }
check_wireguard()         { nmcli connection show 2>/dev/null | grep -qi wireguard; }
check_git_config()        { [[ -n "$(git config --global user.name 2>/dev/null)" ]]; }
check_gh_auth()           { gh auth status &>/dev/null; }
check_fingerprint()       { grep -q 'pam_fprintd' /etc/pam.d/sudo 2>/dev/null && grep -Eq 'fingerprint:enabled[[:space:]]*=[[:space:]]*true' "$HOME/.config/hypr/hyprlock.conf" 2>/dev/null && fprintd-list "$USER" 2>/dev/null | grep -q 'right-index-finger'; }
check_ohmybash()          { [[ -f "${HOME}/.oh-my-bash/oh-my-bash.sh" ]]; }
check_bashrc()            { cmp -s "${SCRIPT_DIR}/.bashrc" "${HOME}/.bashrc"; }
check_nemo_config()       { dconf read /org/nemo/preferences/bulk-rename-tool 2>/dev/null | grep -q 'bulky'; }
check_dotfiles()          { [[ -f "${HOME}/.vimrc" && -f "${HOME}/.tmux.conf" && -f "${HOME}/.bash_profile" && -f "${HOME}/.config/hypr/hyprland.lua" && -f "${HOME}/.config/waybar/config.jsonc" && -d "${HOME}/.config/alacritty" ]]; }
check_default_apps()      { xdg-mime query default text/html 2>/dev/null | grep -q firefox; }
check_nvm()               { (load_nvm && [[ "$(nvm version default)" != "N/A" ]]) &>/dev/null; }
check_vtop()              { (load_nvm && nvm use default && cmd_exists vtop) &>/dev/null; }
check_docker()            { systemctl is-enabled docker.service &>/dev/null; }
check_pcloud()            { cmd_exists pcloud; }
check_discord()           { [[ -d "${HOME}/.config/BetterDiscord" ]]; }
check_spotify()           { is_marked "spotify_setup"; }
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
    install_monocraft
    configure_fonts --system "${HOME}/.local/share/fonts/Monocraft-nerd-fonts-patched.ttc"
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

# Shared by the desktop font and system-font installer tasks.
font_command() {
    if [[ ${FONT_SYSTEM:-false} == true ]]; then sudo "$@"; else "$@"; fi
}

font_read() {
    if font_command test -f "$1"; then font_command cat "$1"; fi
}

font_install() {
    local source=$1 target=$2
    font_command cmp -s "$source" "$target" && return 0
    if ! grep -Fxq -- "$target" "$FONT_STAGE/backed-up" 2>/dev/null; then
        if font_command test -e "$target"; then
            font_command mkdir -p "$FONT_BACKUP${target%/*}"
            font_command cp -p "$target" "$FONT_BACKUP$target"
        else
            printf '%s\n' "$target" | font_command tee -a "$FONT_BACKUP/created-files.txt" >/dev/null
        fi
        printf '%s\n' "$target" >> "$FONT_STAGE/backed-up"
    fi
    font_command install -Dm644 "$source" "$target"
    printf 'Updated %s\n' "$target"
}

# Update one INI key while retaining other sections, settings and comments.
font_ini() {
    local target=$1 section=$2 key=$3 value=$4
    font_read "$target" | awk -v section="$section" -v key="$key" -v value="$value" '
        function finish() { if (inside && !written) { print key "=" value; written=1 } }
        /^[[:space:]]*\[/ {
            finish()
            name=$0; sub(/^[[:space:]]*\[/, "", name); sub(/\].*$/, "", name)
            inside=(name==section); if (inside) found=1
        }
        {
            name=$0; sub(/=.*/, "", name); gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            if (inside && index($0,"=") && name==key) {
                if (!written) print key "=" value
                written=1; next
            }
            print
        }
        END { finish(); if (!found) { print "[" section "]"; print key "=" value } }
    ' > "$FONT_STAGE/settings.ini"
    font_install "$FONT_STAGE/settings.ini" "$target"
}

font_desktop() {
    local family='Monocraft Nerd Font' version key schema value actual
    [[ $EUID != 0 ]] || { print_error 'Run desktop font setup without sudo'; return 1; }
    [[ $(fc-match -f '%{family}' "$family") == *"$family"* ]] || {
        print_error 'Install Monocraft Nerd Font first'; return 1;
    }
    font_install "$SCRIPT_DIR/.config/fontconfig/conf.d/99-monocraft.conf" "$HOME/.config/fontconfig/conf.d/99-monocraft.conf"
    for version in 3.0 4.0; do
        font_ini "$HOME/.config/gtk-$version/settings.ini" Settings gtk-font-name "$family 10"
    done
    { font_read "$HOME/.gtkrc-2.0" | awk '!/^[[:space:]]*gtk-font-name[[:space:]]*=/'; printf 'gtk-font-name="%s 10"\n' "$family"; } > "$FONT_STAGE/gtkrc"
    font_install "$FONT_STAGE/gtkrc" "$HOME/.gtkrc-2.0"
    for version in 5 6; do
        for key in fixed general; do
            font_ini "$HOME/.config/qt${version}ct/qt${version}ct.conf" Fonts "$key" "\"$family,10,-1,5,50,0,0,0,0,0\""
        done
    done
    while read -r schema key value; do
        gsettings list-schemas | grep -Fx "$schema" >/dev/null || continue
        gsettings list-keys "$schema" | grep -Fx "$key" >/dev/null || continue
        printf '%s %s %s\n' "$schema" "$key" "$(gsettings get "$schema" "$key")" >> "$FONT_BACKUP/gsettings.txt"
        gsettings set "$schema" "$key" "$value"
    done <<'SETTINGS'
org.gnome.desktop.interface font-name Monocraft Nerd Font 10
org.gnome.desktop.interface document-font-name Monocraft Nerd Font 10
org.gnome.desktop.interface monospace-font-name Monocraft Nerd Font 10
org.gnome.desktop.wm.preferences titlebar-font Monocraft Nerd Font Bold 10
SETTINGS
    fc-cache -f
    for family in sans-serif serif monospace Arial 'Adwaita Sans'; do
        actual=$(fc-match -f '%{family}' "$family")
        [[ $actual == *'Monocraft Nerd Font'* ]] || { print_error "Font check failed: $family -> $actual"; return 1; }
        printf '%s -> %s\n' "$family" "$actual"
    done
    if command -v makoctl >/dev/null; then makoctl reload || :; fi
}

font_system() {
    local source=$1 theme=/usr/share/plymouth/themes/hexagon_hud item
    local target=/usr/share/plymouth/themes/hexagon_hud_monocraft
    local font=/usr/local/share/fonts/Monocraft-nerd-fonts-patched.ttc
    local conf=/etc/fonts/conf.d/99-monocraft.conf console=/usr/share/kbd/consolefonts/monocraft.psf
    [[ -s $source && -s $SCRIPT_DIR/assets/fonts/monocraft.psf ]] || { print_error 'Missing Monocraft font asset'; return 1; }
    sed -E 's/Image\.Text\(([^;]*),[[:space:]]*1,[[:space:]]*1,[[:space:]]*1\)/Image.Text(\1, 1, 1, 1, 1, "Monocraft Nerd Font 12")/g' \
        "$theme/hexagon_hud.script" > "$FONT_STAGE/hexagon_hud.script"
    [[ $(grep -c 'Monocraft Nerd Font 12' "$FONT_STAGE/hexagon_hud.script") == 5 ]] || {
        print_error 'Unexpected Plymouth theme: expected five text calls'; return 1;
    }
    font_install "$source" "$font"
    font_install "$SCRIPT_DIR/.config/fontconfig/conf.d/99-monocraft.conf" "$conf"
    font_install "$SCRIPT_DIR/assets/fonts/monocraft.psf" "$console"
    { font_read /etc/vconsole.conf | awk '!/^[[:space:]]*FONT[[:space:]]*=/'; printf 'FONT=monocraft\n'; } > "$FONT_STAGE/vconsole.conf"
    font_install "$FONT_STAGE/vconsole.conf" /etc/vconsole.conf
    while IFS= read -r -d '' item; do
        # Install each final file only once, so reruns retain the original backup.
        [[ $item != "$theme/hexagon_hud.script" ]] || continue
        font_install "$item" "$target/${item#"$theme/"}"
    done < <(find "$theme" -type f -print0)
    font_install "$FONT_STAGE/hexagon_hud.script" "$target/hexagon_hud.script"
    { sed "s|$theme|$target|g" "$theme/hexagon_hud.plymouth"; printf '\nFont=Monocraft Nerd Font 12\nMonospaceFont=Monocraft Nerd Font 12\n'; } > "$FONT_STAGE/hexagon_hud_monocraft.plymouth"
    font_install "$FONT_STAGE/hexagon_hud_monocraft.plymouth" "$target/hexagon_hud_monocraft.plymouth"
    font_ini /etc/plymouth/plymouthd.conf Daemon Theme hexagon_hud_monocraft
    printf 'install_items+=" %s %s %s /etc/vconsole.conf "\n' "$font" "$conf" "$console" > "$FONT_STAGE/dracut.conf"
    font_install "$FONT_STAGE/dracut.conf" /etc/dracut.conf.d/30-monocraft.conf
}

configure_fonts() (
    set -e -o pipefail
    local FONT_SYSTEM=false FONT_BACKUP FONT_STAGE parent
    FONT_STAGE=$(mktemp -d)
    trap 'rm -rf -- "$FONT_STAGE"' EXIT
    if [[ ${1:-} == --system ]]; then
        [[ $# == 2 ]] || { print_error 'System font setup requires the font file'; return 1; }
        FONT_SYSTEM=true; parent=/var/lib/dots/backups
    else
        [[ $# == 0 ]] || { print_error 'Unknown font setup option'; return 1; }
        parent=$HOME/.local/state/dots/backups
    fi
    font_command mkdir -p "$parent"
    FONT_BACKUP=$(font_command mktemp -d "$parent/fonts.XXXXXXXX")
    printf 'Backup: %s\n' "$FONT_BACKUP"
    if $FONT_SYSTEM; then
        font_system "$2"
        font_command fc-cache -f
    else
        font_desktop
    fi
)

install_monocraft() {
    print_header "Installing Monocraft Nerd Font"
    mkdir -p "${HOME}/.local/share/fonts"
    print_step "Downloading font if missing..."
    [[ -s ${HOME}/.local/share/fonts/Monocraft-nerd-fonts-patched.ttc ]] || curl -fL -o "${HOME}/.local/share/fonts/Monocraft-nerd-fonts-patched.ttc" \
        https://github.com/IdreesInc/Monocraft/releases/download/v4.0/Monocraft-nerd-fonts-patched.ttc
    print_step "Refreshing font cache..."
    fc-cache
    fc-list | grep -i monocraft
    configure_fonts
    print_success "Monocraft font installed and desktop defaults applied"
}

install_system_fonts() {
    print_header "Configure Monocraft throughout the system"
    install_monocraft
    configure_fonts --system "${HOME}/.local/share/fonts/Monocraft-nerd-fonts-patched.ttc"
    rebuild_initramfs
    print_success "System fonts configured; reboot to use the boot and console fonts"
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
    # Hyprlock uses its native fingerprint listener in parallel with password
    # authentication. Do not add pam_fprintd to its serial PAM stack.
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
        BetterDiscord alacritty fontconfig gtk-3.0 gtk-4.0 hypr keepassxc mako \
        opencode qt5ct qt6ct systemd uwsm waybar; do
        cp -rf "${SCRIPT_DIR}/.config/${config_dir}" "${HOME}/.config/"
    done
    if [[ -f $HOME/.config/hypr/monitors.py ]]; then
        local monitor_backup
        monitor_backup=$(mktemp "$HOME/.config/hypr/monitors.py.backup.XXXXXXXX")
        cp -p "$HOME/.config/hypr/monitors.py" "$monitor_backup"
        rm -- "$HOME/.config/hypr/monitors.py"
    fi
    systemctl --user disable --now dots-rofi.service 2>/dev/null || :
    systemctl --user disable --now dots-desktop.service 2>/dev/null || :
    systemctl --user disable --now desktop-utils.service 2>/dev/null || :
    systemctl --user disable --now utils.service 2>/dev/null || :
    systemctl --user disable --now dots-utils.service 2>/dev/null || :
    systemctl --user stop 'dots-rofi-alert-*.service' 'dots-desktop-alert-*.service' 'desktop-utils-alert-*.service' 'utils-alert-*.service' 'dots-utils-alert-*.service' dots-rofi-ai.service 2>/dev/null || :
    bash "${SCRIPT_DIR}/scripts/migrate-rofi.sh"
    local source_file relative
    while IFS= read -r -d '' source_file; do
        relative=${source_file#"${SCRIPT_DIR}/"}
        [[ $relative != */settings.json || ! -f $HOME/$relative ]] || continue
        mkdir -p "$HOME/${relative%/*}"
        cp -p "$source_file" "$HOME/$relative"
    done < <(find "${SCRIPT_DIR}/.config/rofi" -type f -print0)
    bash "$HOME/.config/rofi/icon-gen/generate.sh" --offline
    if [[ -f $HOME/.config/rofi/config.rasi ]]; then
        cp -p "$HOME/.config/rofi/config.rasi" "$HOME/.config/rofi/config.rasi.backup-$(date +%Y%m%d-%H%M%S)"
        rm -- "$HOME/.config/rofi/config.rasi"
    fi
    cp -rf "${SCRIPT_DIR}/.oh-my-bash/" "$HOME/"
    cp -rf "${SCRIPT_DIR}/.vim/" "$HOME/"

    print_step "Copying dotfiles..."
    cp -f \
        "${SCRIPT_DIR}/.bash_profile" \
        "${SCRIPT_DIR}/.tmux.conf" \
        "${SCRIPT_DIR}/.vimrc" ~

    systemctl --user daemon-reload
    rm -f -- "$HOME/.config/systemd/user/dots-utils.service" "$HOME/.config/rofi/utils/worker.sh" "$HOME/.config/rofi/modi/tray.sh"
    systemctl --user daemon-reload
    bash "$HOME/.config/rofi/modi/time.sh" reconcile
    if [[ -d $HOME/.config/dots-utils ]]; then
        mv "$HOME/.config/dots-utils" "$HOME/.config/dots-utils.backup-$(date +%Y%m%d-%H%M%S)"
    fi
    local retired backup
    backup=$(mktemp -d "${HOME}/.config/rofi-layout-backup.XXXXXXXX")
    for retired in utils icon-gen/icons/LICENSE icon-gen/LICENSE; do
        [[ -e $HOME/.config/rofi/$retired ]] || continue
        mkdir -p "$backup/$(dirname "$retired")"
        mv "$HOME/.config/rofi/$retired" "$backup/$retired"
    done
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

load_nvm() {
    export NVM_DIR="${HOME}/.nvm"
    if [[ ! -s "${NVM_DIR}/nvm.sh" ]]; then
        print_error "NVM is missing from ${NVM_DIR}. Run the nvm + Node.js task first."
        return 1
    fi
    # shellcheck source=/dev/null
    source "${NVM_DIR}/nvm.sh" || return
    declare -F nvm >/dev/null || {
        print_error "NVM failed to load from ${NVM_DIR}/nvm.sh"
        return 1
    }
}

install_nvm() {
    print_header "Installing nvm + Node.js"
    print_step "Installing nvm..."
    export NVM_DIR="${HOME}/.nvm"
    mkdir -p "$NVM_DIR" || return
    # The repository's .bashrc loads NVM; don't let its installer append to it.
    (set -o pipefail; curl -fL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | PROFILE=/dev/null bash) || return
    load_nvm || return
    print_step "Installing latest Node.js..."
    nvm install node || return
    nvm alias default node || return
    print_success "nvm and Node.js installed"
}

install_vtop() {
    print_header "Installing vtop"
    load_nvm || return
    nvm use default || return
    npm install -g vtop || return
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
  Add cookies exceptions (google,github,...)
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
    systemctl --user enable llama-cpp.service
    systemctl --user restart llama-cpp.service
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
    "Configure system fonts (desktop, Plymouth, console)"
    "Set static DNS"
    "Configure Git"
    "Install oh-my-bash"
    "Configure .bashrc"
    "Configure Nemo"
    "Copy dotfiles"
    "Set default applications"
    "Install nvm + Node.js"
    "Install vtop"
    "Set up Docker"
    "Start llama.cpp service"
    "Set up pCloud"
    "Authenticate GitHub CLI"
    "Set up fingerprint auth"
    "Set up Discord + BetterDiscord"
    "Set up Spotify"
    "Set up VSCode"
    "Set up Firefox"
    "Set up Steam"
    "Configure WireGuard VPN"
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
    check_system_fonts
    check_dns
    check_git_config
    check_ohmybash
    check_bashrc
    check_nemo_config
    check_dotfiles
    check_default_apps
    check_nvm
    check_vtop
    check_docker
    check_llama_cpp
    check_pcloud
    check_gh_auth
    check_fingerprint
    check_discord
    check_spotify
    check_vscode
    check_firefox
    check_steam
    check_wireguard
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
    install_system_fonts
    install_dns
    install_git_config
    install_ohmybash
    install_bashrc
    install_nemo_config
    install_dotfiles
    install_default_apps
    install_nvm
    install_vtop
    install_docker
    install_llama_cpp
    install_pcloud
    install_gh_auth
    install_fingerprint
    install_discord
    install_spotify
    install_vscode
    install_firefox
    install_steam
    install_wireguard
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

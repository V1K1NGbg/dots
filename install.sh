#!/bin/bash

# Arch Linux Setup Script - Enhanced Version
# Author: V1K1NGbg
# Description: Automated setup script for Arch Linux with AwesomeWM
# Usage: ./install.sh [--help] [--dry-run] [--skip-gui]

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ==================== CONFIGURATION ====================

# Default configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${HOME}/setup.log"
readonly BACKUP_DIR="${HOME}/.config_backup_$(date +%Y%m%d_%H%M%S)"
readonly USER_NAME="${USER}"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration flags
DRY_RUN=false
SKIP_GUI=false
VERBOSE=false

# ==================== HELPER FUNCTIONS ====================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $*${NC}" | tee -a "${LOG_FILE}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*${NC}" | tee -a "${LOG_FILE}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*${NC}" | tee -a "${LOG_FILE}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*${NC}" | tee -a "${LOG_FILE}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running on Arch Linux
    if [[ ! -f /etc/arch-release ]]; then
        error "This script is designed for Arch Linux only!"
        exit 1
    fi
    
    # Check if running as non-root user
    if [[ $EUID -eq 0 ]]; then
        error "Don't run this script as root! It will use sudo when needed."
        exit 1
    fi
    
    # Check if X11 is running (unless skipping GUI)
    if [[ "$SKIP_GUI" == false ]] && [[ -z "${DISPLAY:-}" ]]; then
        error "X11 environment not detected! Please run in a graphical session or use --skip-gui"
        exit 1
    fi
    
    # Check internet connection
    if ! ping -c 1 google.com &> /dev/null; then
        error "No internet connection detected!"
        exit 1
    fi
    
    # Check if git is available
    if ! command_exists git; then
        warn "Git not found. Installing git first..."
        sudo pacman -S --needed git
    fi
    
    log "Prerequisites check passed!"
}

# Function to create backup
create_backup() {
    log "Creating backup of existing configurations..."
    mkdir -p "${BACKUP_DIR}"
    
    # Backup important config directories if they exist
    local dirs_to_backup=(
        "${HOME}/.config/awesome"
        "${HOME}/.config/alacritty" 
        "${HOME}/.vim"
        "${HOME}/.bashrc"
        "${HOME}/.vimrc"
        "${HOME}/.tmux.conf"
    )
    
    for dir in "${dirs_to_backup[@]}"; do
        if [[ -e "$dir" ]]; then
            cp -r "$dir" "${BACKUP_DIR}/" 2>/dev/null || warn "Failed to backup $dir"
        fi
    done
    
    log "Backup created at: ${BACKUP_DIR}"
}

# Function to execute command with proper error handling
safe_execute() {
    local description="$1"
    shift
    local cmd=("$@")
    
    log "Executing: $description"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would execute: ${cmd[*]}"
        return 0
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        info "Running command: ${cmd[*]}"
    fi
    
    if "${cmd[@]}" 2>&1 | tee -a "${LOG_FILE}"; then
        log "✓ Completed: $description"
        return 0
    else
        error "✗ Failed: $description"
        return 1
    fi
}

# Function to prompt user with default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local response
    
    read -p "$prompt [$default]: " response
    echo "${response:-$default}"
}

# Function to confirm action
confirm() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$prompt (y/N): " response
        case $response in
            [Yy]* ) return 0;;
            [Nn]* | "" ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Arch Linux Setup Script - Enhanced Version

OPTIONS:
    --help          Show this help message
    --dry-run       Show what would be done without executing
    --skip-gui      Skip GUI applications and configurations
    --verbose       Enable verbose output
    
EXAMPLES:
    $0                    # Run full installation
    $0 --dry-run         # See what would be installed
    $0 --skip-gui        # Install only CLI tools and configs

EOF
}

# ==================== MAIN FUNCTIONS ====================

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_usage
                exit 0
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-gui)
                SKIP_GUI=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# ==================== START OF SCRIPT ====================

# Parse command line arguments
parse_arguments "$@"

log "Starting Arch Linux setup script..."
log "Log file: ${LOG_FILE}"

if [[ "$DRY_RUN" == true ]]; then
    warn "DRY RUN MODE - No changes will be made!"
fi

# Check prerequisites
check_prerequisites

# Create backup
if [[ "$DRY_RUN" == false ]]; then
    create_backup
fi

# Confirm before proceeding
if [[ "$DRY_RUN" == false ]]; then
    echo
    info "This script will install and configure a complete Arch Linux environment."
    info "GUI applications will be $([ "$SKIP_GUI" == true ] && echo "SKIPPED" || echo "INCLUDED")"
    echo
    if ! confirm "Do you want to continue?"; then
        log "Installation cancelled by user"
        exit 0
    fi
fi

# ==================== INSTALLATION FUNCTIONS ====================

setup_multilib() {
    log "Setting up multilib repository for Steam..."
    safe_execute "Enable multilib repository" \
        sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
}

update_system() {
    log "Updating system packages..."
    safe_execute "Update package database and system" \
        sudo pacman -Syu --noconfirm
}

install_paru() {
    if command_exists paru; then
        log "Paru already installed, skipping..."
        return 0
    fi
    
    log "Installing Paru AUR helper..."
    safe_execute "Install base-devel" \
        sudo pacman -S --needed --noconfirm base-devel
        
    local temp_dir=$(mktemp -d)
    pushd "$temp_dir" >/dev/null
    
    safe_execute "Clone paru repository" \
        git clone https://aur.archlinux.org/paru-git.git
    
    pushd paru-git >/dev/null
    safe_execute "Build and install paru" \
        makepkg -si --noconfirm
    popd >/dev/null
    popd >/dev/null
    
    rm -rf "$temp_dir"
}

update_awesome() {
    log "Updating AwesomeWM to git version..."
    if pacman -Q awesome &>/dev/null; then
        safe_execute "Remove old awesome" \
            sudo pacman -Rs --noconfirm awesome
    fi
    safe_execute "Install awesome-git" \
        paru -S --noconfirm awesome-git
}

install_core_packages() {
    log "Installing core packages..."
    
    local core_packages=(
        # System utilities
        acpi alsa-utils arandr autorandr bash-completion blueman bluez bluez-utils 
        curl cpupower-gui-git git github-cli highlight htop less man-db man-pages 
        nano network-manager-applet nmap tree unzip wget zip
        
        # Development tools
        jdk21-openjdk jdk8-openjdk tmux vim visual-studio-code-bin
        
        # Audio/Video
        pavucontrol pasystray playerctl vlc
        
        # Graphics
        vulkan-radeon vulkan-tools sof-firmware
        
        # Fonts
        noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra
        
        # File management
        nemo nemo-compare nemo-fileroller baobab ranger
        
        # Security
        keepassxc
        
        # System monitoring
        nvtop fastfetch
    )
    
    if [[ "$SKIP_GUI" == false ]]; then
        local gui_packages=(
            # GUI applications
            alacritty firefox flameshot gimp discord
            
            # Media
            spotify-launcher steam prismlauncher
            
            # Utilities
            copyq dangerzone-bin localsend pcloud-drive rofi rofi-calc
            
            # Themes and cursors
            capitaine-cursors
            
            # Communication
            spicetify-cli
            
            # Tools
            bulky glava i3lock-color usbimager xdotool xorg-xev 
            xorg-xinput xorg-xset xss-lock meld redshift unclutter
            
            # Fun stuff
            ani-cli cowsay lolcat
            
            # Development
            lazygit fd
            
            # AI/Chat
            aichat
            
            # Other
            imgcat lobster-git ruby-fusuma ruby-fusuma-plugin-sendkey
            plymouth plymouth-theme-hexagon-hud-git qt6-svg uthash
        )
        core_packages+=("${gui_packages[@]}")
    fi
    
    log "Installing ${#core_packages[@]} packages..."
    safe_execute "Install core packages" \
        paru -S --needed --noconfirm "${core_packages[@]}"
}

setup_auto_login() {
    log "Setting up auto-login for user: ${USER_NAME}..."
    
    local auto_login_config="[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin ${USER_NAME} %I %TERM"
    
    safe_execute "Configure auto-login" \
        sudo systemd-edit getty@tty1.service --drop-in=autologin --stdin <<< "$auto_login_config"
}

compile_install_picom() {
    if command_exists picom; then
        log "Picom already installed, skipping compilation..."
        return 0
    fi
    
    log "Compiling and installing custom picom..."
    local temp_dir=$(mktemp -d)
    pushd "$temp_dir" >/dev/null
    
    safe_execute "Clone picom repository" \
        git clone https://github.com/pijulius/picom.git
    
    pushd picom >/dev/null
    safe_execute "Configure picom build" \
        meson setup --buildtype=release build
    safe_execute "Compile picom" \
        ninja -C build
    safe_execute "Install picom" \
        sudo ninja -C build install
    popd >/dev/null
    popd >/dev/null
    
    rm -rf "$temp_dir"
}

setup_framework_laptop() {
    if [[ ! -d /sys/firmware/efi ]]; then
        warn "UEFI not detected, skipping framework laptop setup..."
        return 0
    fi
    
    log "Setting up Framework laptop optimizations..."
    local boot_entry=$(ls /boot/loader/entries/ | head -1)
    
    if [[ -n "$boot_entry" ]]; then
        safe_execute "Add AMD GPU debug mask" \
            sudo sed -i 's/^options .*/& amdgpu.dcdebugmask=0x10/' "/boot/loader/entries/$boot_entry"
    else
        warn "No boot entries found, skipping framework setup"
    fi
}

setup_plymouth() {
    log "Setting up Plymouth boot splash..."
    local boot_entry=$(ls /boot/loader/entries/ | head -1)
    
    if [[ -n "$boot_entry" ]]; then
        safe_execute "Add plymouth to boot options" \
            sudo sed -i 's/^options .*/& quiet splash/' "/boot/loader/entries/$boot_entry"
        safe_execute "Add plymouth to mkinitcpio hooks" \
            sudo sed -i 's/HOOKS=(\([^)]*\)encrypt\([^)]*\))/HOOKS=(\1plymouth encrypt\2)/' /etc/mkinitcpio.conf
        safe_execute "Regenerate initramfs" \
            sudo dracut
        safe_execute "Set plymouth theme" \
            sudo plymouth-set-default-theme -R hexagon_hud
    else
        warn "No boot entries found, skipping plymouth setup"
    fi
}

setup_git() {
    log "Setting up Git configuration..."
    
    local git_name=$(prompt_with_default "Enter your Git name" "V1K1NGbg")
    local git_email=$(prompt_with_default "Enter your Git email" "victor@ilchev.com")
    
    safe_execute "Configure Git user" \
        git config --global user.name "$git_name"
    safe_execute "Configure Git email" \
        git config --global user.email "$git_email"
    
    # Create GitHub directory
    mkdir -p ~/Documents/GitHub
    
    if command_exists gh; then
        if confirm "Do you want to authenticate with GitHub CLI now?"; then
            gh auth login
        fi
    fi
}

setup_services() {
    log "Enabling and starting system services..."
    
    local services=(
        "bluetooth.service"
    )
    
    if [[ "$SKIP_GUI" == false ]]; then
        services+=("docker.service")
    fi
    
    for service in "${services[@]}"; do
        safe_execute "Enable $service" \
            sudo systemctl enable "$service"
        safe_execute "Start $service" \
            sudo systemctl start "$service"
    done
}

install_oh_my_bash() {
    if [[ -d "${HOME}/.oh-my-bash" ]]; then
        log "Oh My Bash already installed, skipping..."
        return 0
    fi
    
    log "Installing Oh My Bash..."
    safe_execute "Install Oh My Bash" \
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"
}

setup_touchpad() {
    log "Configuring touchpad settings..."
    
    local touchpad_config='        Option "Tapping" "on"
        Option "NaturalScrolling" "true"
        Option "ClickMethod" "clickfinger"'
    
    safe_execute "Configure touchpad" \
        sudo sed -i '/Section "InputClass"/,/EndSection/ {
            /Identifier.*touchpad/,/EndSection/ {
            /Driver "libinput"/a\
'"$touchpad_config"'
            }
        }' /usr/share/X11/xorg.conf.d/40-libinput.conf
}

setup_keyboard_layout() {
    log "Setting up keyboard layouts (US + Bulgarian)..."
    
    local keyboard_config='        Option "XkbVariant" ",bas_phonetic"'
    
    if [[ ! -f /etc/X11/xorg.conf.d/00-keyboard.conf ]]; then
        warn "Keyboard config file not found, creating one..."
        sudo mkdir -p /etc/X11/xorg.conf.d/
        sudo tee /etc/X11/xorg.conf.d/00-keyboard.conf > /dev/null << 'EOF'
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "us,bg"
        Option "XkbVariant" ",bas_phonetic"
EndSection
EOF
    else
        safe_execute "Configure keyboard layout" \
            sudo sed -i '/Section "InputClass"/,/EndSection/ {
                /Identifier.*system-keyboard/,/EndSection/ {
                s/Option "XkbLayout".*$/Option "XkbLayout" "us,bg"/
                /Option "XkbLayout"/a\
'"$keyboard_config"'
                }
            }' /etc/X11/xorg.conf.d/00-keyboard.conf
    fi
}

install_monocraft_font() {
    log "Installing Monocraft font..."
    
    local font_dir="${HOME}/.local/share/fonts"
    local font_file="Monocraft-nerd-fonts-patched.ttc"
    local font_url="https://github.com/IdreesInc/Monocraft/releases/download/v4.0/Monocraft-nerd-fonts-patched.ttc"
    
    mkdir -p "$font_dir"
    
    if [[ -f "$font_dir/$font_file" ]]; then
        log "Monocraft font already installed, skipping..."
        return 0
    fi
    
    safe_execute "Download Monocraft font" \
        curl -L -o "$font_dir/$font_file" "$font_url"
    safe_execute "Update font cache" \
        fc-cache -f
    
    # Verify installation
    if fc-list | grep -q Monocraft; then
        log "✓ Monocraft font installed successfully"
    else
        warn "Monocraft font installation verification failed"
    fi
}

setup_fusuma() {
    log "Setting up Fusuma gesture recognition..."
    
    safe_execute "Add user to input group" \
        sudo gpasswd -a "$USER_NAME" input
    
    mkdir -p ~/.config/fusuma
    log "Fusuma setup complete. You may need to log out and back in for group changes to take effect."
}

setup_networking() {
    log "Configuring static DNS servers..."
    
    local dns_config='[global-dns-domain-*]
servers=1.1.1.1,1.0.0.1'
    
    safe_execute "Configure DNS servers" \
        sudo tee /etc/NetworkManager/conf.d/dns-servers.conf > /dev/null <<< "$dns_config"
}

setup_fingerprint() {
    if [[ ! -d /sys/class/dmi/id ]] || ! command_exists fprintd-enroll; then
        warn "Fingerprint hardware not detected or fprintd not installed, skipping..."
        return 0
    fi
    
    log "Setting up fingerprint authentication..."
    
    if confirm "Do you want to enroll your fingerprint now?"; then
        safe_execute "Enroll fingerprint" \
            sudo fprintd-enroll "$USER_NAME"
        
        safe_execute "Configure sudo for fingerprint" \
            sudo sed -i '/#%PAM-1.0/a auth            sufficient      pam_fprintd.so' /etc/pam.d/sudo
        
        safe_execute "Configure i3lock for fingerprint" \
            sudo sed -i '/auth include system-local-login/i auth sufficient pam_unix.so try_first_pass likeauth nullok\nauth sufficient pam_fprintd.so timeout=10' /etc/pam.d/i3lock
    fi
}

setup_config_files() {
    log "Setting up configuration files..."
    
    if [[ ! -d "$SCRIPT_DIR" ]]; then
        error "Script directory not found: $SCRIPT_DIR"
        return 1
    fi
    
    pushd "$SCRIPT_DIR" >/dev/null
    
    # Setup Nemo configuration
    if [[ -f "nemo_config" ]]; then
        safe_execute "Import Nemo configuration" \
            dconf load /org/nemo/ < nemo_config
    fi
    
    # Create necessary directories
    local config_dirs=(
        ~/.config/awesome
        ~/.config/alacritty
        ~/.vim/colors
        ~/Documents/BackUp/screenshots
        ~/Documents/BackUp
        ~/Documents/PC
        ~/.screenlayout
    )
    
    for dir in "${config_dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    # Copy configuration files if they exist
    local config_files=(
        ".config/"
        ".oh-my-bash/"
        ".vim/"
        ".screenlayout/"
        ".bash_profile"
        ".tmux.conf"
        ".vimrc"
        ".Xresources"
        "i3lock.sh"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -e "$file" ]]; then
            if [[ -d "$file" ]]; then
                safe_execute "Copy $file directory" \
                    cp -rf "$file" ~/
            else
                safe_execute "Copy $file" \
                    cp -f "$file" ~/
            fi
        else
            warn "Configuration file/directory not found: $file"
        fi
    done
    
    # Handle awesome configuration
    local awesome_config
    if [[ -f ~/.config/awesome/rc.lua ]]; then
        log "Awesome config already exists, skipping..."
    else
        awesome_config=$(prompt_with_default "Enter path to awesome config file" "$SCRIPT_DIR/rc.lua")
        if [[ -f "$awesome_config" ]]; then
            safe_execute "Copy awesome configuration" \
                cp -f "$awesome_config" ~/.config/awesome/
        else
            warn "Awesome config file not found: $awesome_config"
        fi
    fi
    
    # Setup bashrc
    if [[ -f .bashrc ]]; then
        safe_execute "Backup original bashrc" \
            cp ~/.bashrc ~/.bashrc.backup
        safe_execute "Remove source lines from bashrc" \
            grep -v "source" ~/.bashrc > tmpfile && mv tmpfile ~/.bashrc
        safe_execute "Append custom bashrc" \
            cat .bashrc >> ~/.bashrc
    fi
    
    # Setup terminal key binding
    safe_execute "Configure Ctrl+Backspace in terminal" \
        echo '"\C-H":"\C-W"' | sudo tee -a /etc/inputrc
    
    # Make i3lock script executable
    if [[ -f ~/i3lock.sh ]]; then
        chmod +x ~/i3lock.sh
    fi
    
    popd >/dev/null
}

setup_pcloud() {
    if [[ "$SKIP_GUI" == true ]]; then
        log "Skipping pCloud setup (GUI disabled)"
        return 0
    fi
    
    log "Setting up pCloud..."
    
    if command_exists pcloud; then
        if confirm "Do you want to set up pCloud now?"; then
            pcloud > /dev/null 2>&1 &
            echo
            info "Please log in to pCloud in the GUI that opened."
            info "Recommended sync setup:"
            info "  - Sync ~/Documents/PC <-> pCloudDrive/PC"
            info "  - Backup ~/Documents/BackUp"
            read -p "Press Enter after setting up pCloud..."
        fi
    else
        warn "pCloud not installed, skipping setup"
    fi
}

setup_docker() {
    if ! command_exists docker; then
        warn "Docker not installed, skipping setup"
        return 0
    fi
    
    log "Setting up Docker..."
    safe_execute "Add user to docker group" \
        sudo usermod -aG docker "$USER_NAME"
    
    log "Docker setup complete. You may need to log out and back in for group changes to take effect."
}

setup_wireguard() {
    if ! command_exists nmcli; then
        warn "NetworkManager not found, skipping WireGuard setup"
        return 0
    fi
    
    log "Setting up WireGuard VPN..."
    
    local wg_config_path
    wg_config_path=$(prompt_with_default "Enter path to WireGuard config file (or 'skip' to skip)" "skip")
    
    if [[ "$wg_config_path" == "skip" ]] || [[ ! -f "$wg_config_path" ]]; then
        log "Skipping WireGuard setup"
        return 0
    fi
    
    local wg_config_name=$(basename "$wg_config_path" .conf)
    
    safe_execute "Import WireGuard configuration" \
        nmcli connection import type wireguard file "$wg_config_path"
    safe_execute "Disable auto-connect for VPN" \
        nmcli connection modify "$wg_config_name" connection.autoconnect no
}

setup_default_applications() {
    if [[ "$SKIP_GUI" == true ]]; then
        log "Skipping default applications setup (GUI disabled)"
        return 0
    fi
    
    log "Setting up default applications..."
    
    local mime_associations=(
        "text/* code.desktop"
        "text/html firefox.desktop"
        "application/pdf firefox.desktop"
        "video/* vlc.desktop"
        "audio/* vlc.desktop"
        "image/* gimp.desktop"
        "inode/* nemo.desktop"
    )
    
    for association in "${mime_associations[@]}"; do
        local mime_type="${association% *}"
        local app="${association#* }"
        safe_execute "Set default app for $mime_type" \
            xdg-mime default "$app" "$mime_type"
    done
}

install_node_tools() {
    log "Installing Node.js and tools..."
    
    if [[ ! -d "${HOME}/.nvm" ]]; then
        safe_execute "Install NVM" \
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        
        # Source nvm for current session
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        
        safe_execute "Install latest Node.js" \
            nvm install node
        safe_execute "Install vtop" \
            npm install -g vtop
    else
        log "NVM already installed, skipping..."
    fi
}

setup_gui_applications() {
    if [[ "$SKIP_GUI" == true ]]; then
        log "Skipping GUI application setup (GUI disabled)"
        return 0
    fi
    
    log "Setting up GUI applications..."
    
    # Discord
    if command_exists discord && confirm "Do you want to set up Discord now?"; then
        log "Starting Discord for initial setup..."
        discord > /dev/null 2>&1 &
        echo
        info "Please log in to Discord in the window that opened."
        info "Also consider installing BetterDiscord from: https://betterdiscord.app/"
        read -p "Press Enter after setting up Discord..."
        pkill -f discord || true
    fi
    
    # Spotify
    if command_exists spotify-launcher && confirm "Do you want to set up Spotify now?"; then
        log "Starting Spotify for initial setup..."
        spotify-launcher > /dev/null 2>&1 &
        echo
        info "Please log in to Spotify and disable song change notifications."
        read -p "Press Enter after setting up Spotify..."
        pkill -f spotify || true
        
        # Spicetify
        if command_exists spicetify; then
            safe_execute "Setup Spicetify" \
                bash -c "spicetify backup apply && spicetify config current_theme Ziro && spicetify apply"
        fi
    fi
    
    # VS Code
    if command_exists code && confirm "Do you want to set up VS Code now?"; then
        log "Starting VS Code for initial setup..."
        code > /dev/null 2>&1 &
        echo
        info "Please log in to VS Code and sync your settings."
        info "Wait for the sync to finish before continuing."
        read -p "Press Enter after setting up VS Code..."
        pkill -f code || true
    fi
    
    # CopyQ
    if command_exists copyq && confirm "Do you want to set up CopyQ clipboard manager now?"; then
        log "Starting CopyQ for initial setup..."
        copyq &
        echo
        info "Please import your CopyQ configuration."
        info "Set up shortcuts as needed (especially 'Window under mouse')."
        read -p "Press Enter after setting up CopyQ..."
        pkill -f copyq || true
    fi
    
    # Firefox
    if command_exists firefox && confirm "Do you want to set up Firefox now?"; then
        log "Starting Firefox for initial setup..."
        firefox > /dev/null 2>&1 &
        echo
        info "Firefox setup checklist:"
        info "  - Log in and sync settings"
        info "  - Import Vimium and Bonjourr configs"
        info "  - Fix persistent tabs"
        info "  - Fix bookmarks layout"
        info "  - Set DuckDuckGo as default search engine"
        info "  - Add cookie exceptions (Google, GitHub, University, Netflix)"
        read -p "Press Enter after completing Firefox setup..."
        pkill -f firefox || true
    fi
    
    # Steam
    if command_exists steam && confirm "Do you want to set up Steam now? (This may take a while)"; then
        log "Starting Steam for initial setup..."
        steam > /dev/null 2>&1 &
        echo
        info "Please log in to Steam. This process may take several minutes."
        read -p "Press Enter after Steam is fully loaded and logged in..."
        pkill -f steam || true
    fi
}

setup_docker_containers() {
    if [[ ! -f "${SCRIPT_DIR}/docker-compose.yml" ]]; then
        warn "docker-compose.yml not found in ${SCRIPT_DIR}, skipping container setup"
        return 0
    fi
    
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        warn "Docker Compose not available, skipping container setup"
        return 0
    fi
    
    log "Setting up Docker containers..."
    
    pushd "$SCRIPT_DIR" >/dev/null
    
    safe_execute "Start Docker containers" \
        docker compose up -d
    
    # Pull Ollama models if Ollama is in the compose file
    if grep -q ollama docker-compose.yml; then
        log "Pulling Ollama models..."
        local ollama_models=(
            "qwen2.5:8b"
            "qwen2.5:14b" 
            "qwen2.5:32b"
            "qwen2.5-coder:7b"
        )
        
        for model in "${ollama_models[@]}"; do
            safe_execute "Pull Ollama model: $model" \
                curl -X POST http://localhost:11434/api/pull -d "{\"model\": \"$model\"}"
        done
    fi
    
    popd >/dev/null
}

show_completion_summary() {
    log "================================================="
    log "Installation completed successfully!"
    log "================================================="
    echo
    info "Backup created at: ${BACKUP_DIR}"
    info "Log file: ${LOG_FILE}"
    echo
    info "Post-installation notes:"
    info "  - Some group changes require logout/login to take effect"
    info "  - Reboot is recommended to ensure all changes are applied"
    info "  - Docker containers (if configured) should be running"
    echo
    
    if [[ -f "${SCRIPT_DIR}/docker-compose.yml" ]]; then
        info "Docker containers status:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || true
        echo
    fi
    
    info "Useful post-installation commands:"
    info "  - Monitor setup: arandr"
    info "  - Brightness control: xrandr --output eDP-1 --brightness 0.5"
    info "  - Redshift: redshift -P -O 4500 (or redshift -x to disable)"
    info "  - List packages: paru -Qqen"
    echo
    
    if confirm "Do you want to reboot now to complete the installation?"; then
        log "Rebooting system..."
        sudo reboot
    else
        log "Setup complete! Please reboot when convenient."
    fi
}

# ==================== MAIN EXECUTION ====================

main() {
    # Change to home directory
    cd ~
    
    # Update system and setup package manager
    setup_multilib
    update_system
    install_paru
    
    # Install packages and update awesome
    update_awesome
    install_core_packages
    
    # System configuration
    setup_auto_login
    compile_install_picom
    setup_framework_laptop
    setup_plymouth
    
    # User configuration
    setup_git
    setup_services
    install_oh_my_bash
    
    # Hardware configuration
    setup_touchpad
    setup_keyboard_layout
    install_monocraft_font
    setup_fusuma
    setup_networking
    setup_fingerprint
    
    # Application configuration
    setup_config_files
    setup_pcloud
    setup_docker
    setup_wireguard
    setup_default_applications
    install_node_tools
    
    # GUI applications (if not skipped)
    setup_gui_applications
    
    # Docker containers
    setup_docker_containers
    
    # Show completion summary
    show_completion_summary
}

# Run the main function
main

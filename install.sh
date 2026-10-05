#!/bin/bash

# Setup Live USB
#   gpg --keyserver-options auto-key-retrieve --verify archlinux.iso.sig
#   sha256sum archlinux.iso
#   sudo usbimager
#   or
#   sudo dd if=archlinux.iso of=/dev/sdX bs=4M status=progress conv=fsync && sync
#
# Extra packages needed for this installer: git vim firefox less

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"

# Root-only setup shared by the live ISO and desktop installers.
install_lockscreen() (
    set -euo pipefail
    [[ $# == 0 && $EUID == 0 ]] || { echo 'Usage: sudo bash install.sh --install-lockscreen' >&2; exit 1; }
    source_pam=$CONFIG_DIR/system/pam.d/dots-hyprlock
    active=/etc/pam.d/dots-hyprlock
    [[ ! -L $active ]] || { echo 'Refusing symlinked PAM service.' >&2; exit 1; }
    if [[ -e $active ]]; then
        cmp -s "$source_pam" "$active" || { echo 'Existing PAM service differs; this installer does not replace it.' >&2; exit 1; }
        echo 'Dedicated PAM service already installed.'
        exit
    fi
    temporary=$(mktemp /etc/pam.d/dots-hyprlock.XXXXXXXX)
    trap 'rm -f -- "$temporary"' EXIT
    install -m0644 "$source_pam" "$temporary"
    mv -T -- "$temporary" "$active"
    echo 'Dedicated PAM service installed.'
)

setup_power() (
    set -euo pipefail
    [[ $# == 0 && $EUID == 0 ]] || { echo 'Usage: sudo bash install.sh --setup-power' >&2; exit 1; }

    # Check both destinations before writing either. Identical bootstrap copies are OK.
    for kind in sleep logind; do
        target=/etc/systemd/$kind.conf.d/60-dots-power.conf
        [[ ! -L $target ]] || { echo "Refusing symlink: $target" >&2; exit 1; }
        if [[ -e $target ]] && ! cmp -s "$CONFIG_DIR/system/$kind/60-dots-power.conf" "$target"; then
            echo "Existing power policy differs; this installer does not replace it: $target" >&2
            exit 1
        fi
    done
    for kind in sleep logind; do
        target=/etc/systemd/$kind.conf.d/60-dots-power.conf
        [[ -e $target ]] || install -Dm0644 "$CONFIG_DIR/system/$kind/60-dots-power.conf" "$target"
    done
    systemctl --root=/ mask hibernate.target hybrid-sleep.target suspend-then-hibernate.target
    echo 'Initial suspend policy installed; takes effect after reboot.'
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    case "${1:-}" in
        --install-lockscreen) shift; install_lockscreen "$@"; exit $? ;;
        --setup-power) shift; setup_power "$@"; exit $? ;;
    esac
fi

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

installer_windows() {
    [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || return 0
    local result
    if [[ $1 == stop ]]; then
        hyprctl dispatch 'function()
            if dots_installer_windows then
                for _, hook in ipairs(dots_installer_windows) do hook:remove() end
                dots_installer_windows = nil
            end
        end' >/dev/null
        return
    fi
    result=$(hyprctl dispatch 'function()
        local terminal = hl.get_active_window()
        assert(terminal and terminal.class:lower() == "alacritty",
            "Start the installer from the focused Alacritty window")
        if dots_installer_windows then
            for _, hook in ipairs(dots_installer_windows) do hook:remove() end
        end
        local apps = { code = true, ["code-oss"] = true, ["code - oss"] = true,
            ["com.visualstudio.code.oss"] = true, ["com.visualstudio.codeoss"] = true,
            firefox = true, ["org.mozilla.firefox"] = true,
            discord = true, spotify = true, steam = true }
        local function place(window)
            if not window or not terminal.mapped or not terminal.workspace then return end
            local class = window.class:lower()
            if (apps[class] or class:find("pcloud", 1, true))
                and window.workspace ~= terminal.workspace then
                hl.dispatch(hl.dsp.window.move({ window = window,
                    workspace = terminal.workspace, follow = false }))
            end
        end
        dots_installer_windows = {
            hl.on("window.open", place), hl.on("window.active", place),
        }
    end') || return
    [[ $result == ok ]] || { print_error "$result"; return 1; }
}

install_boot_hook() {
    sudo install -Dm0644 "$CONFIG_DIR/system/pacman-hooks/90-dracut-install.hook" \
        /etc/pacman.d/hooks/90-dracut-install.hook
}

rebuild_initramfs() (
    local kernel_cmdline temporary=""
    trap '[[ -z "$temporary" ]] || sudo rm -f -- "$temporary"' EXIT

    kernel_cmdline=$(sudo cat /etc/kernel/cmdline) || return
    kernel_cmdline=${kernel_cmdline//$'\n'/ }
    kernel_cmdline=${kernel_cmdline% }
    if [[ ! "$kernel_cmdline" =~ [^[:space:]] ]]; then
        print_error "Refusing to rebuild with an empty /etc/kernel/cmdline"
        return 1
    fi
    install_boot_hook || return
    sudo install -d -m 0755 /etc/dracut.conf.d || return
    temporary=$(sudo mktemp /etc/dracut.conf.d/20-cmdline.conf.XXXXXXXX) || return
    # dracut sources this as shell code; quote literal command-line characters.
    # Publish only a complete write, leaving the old boot config intact on error.
    printf 'kernel_cmdline=%q\n' "$kernel_cmdline" \
        | sudo tee "$temporary" > /dev/null || return
    sudo chmod 0644 "$temporary" || return
    sudo mv -f "$temporary" /etc/dracut.conf.d/20-cmdline.conf || return
    temporary=""
    sudo dracut --regenerate-all --force
)

# Full package set for the graphical installation stage.
readonly -a REPO_PACKAGES=(
    acpi adw-gtk-theme alacritty alsa-utils aspell aspell-en
    baobab bash-completion blueman bluez bluez-utils brightnessctl btop bulky
    capitaine-cursors cava code
    cliphist clang cowsay curl dconf discord docker docker-compose dracut
    fastfetch fd firefox fprintd fzf gimp git github-cli gnome-disk-utility
    go gopls grim gtk3 gtk-layer-shell highlight htop hypridle hyprland hyprlock hyprpolkitagent hyprsunset
    jdk21-openjdk jdk17-openjdk jdk8-openjdk kdeconnect keepassxc lazygit less libinput
    libarchive libnotify libpulse libqalculate llama-cpp ggml-vulkan lolcat mako
    man-db man-pages meld nano nemo nemo-fileroller networkmanager network-manager-applet nmap
    noto-fonts noto-fonts-cjk noto-fonts-emoji nvtop nwg-displays nwg-look
    pango papirus-icon-theme pavucontrol pipewire pipewire-alsa pkgconf
    pipewire-pulse playerctl plymouth
    poppler power-profiles-daemon prettier
    prismlauncher pyright python python-black python-pillow jq qt5ct qt6ct
    ranger rofi rofi-calc rust rust-analyzer slurp sof-firmware spotify-launcher steam
    swappy tmux tree typescript-language-server unzip vim
    vlc vulkan-radeon lib32-vulkan-radeon vulkan-tools
    waybar wayland wayland-protocols uthash wev wget wireplumber wl-clipboard xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland xdg-utils zip uwsm
)

readonly -a AUR_PACKAGES=(
    ani-cli
    rofi-blocks-git
    imgcat
    opencode
    pcloud-drive
    plymouth-theme-hexagon-hud-git
    usbimager
    wl_shimeji-git
)

readonly -a PACKAGES=("${REPO_PACKAGES[@]}" "${AUR_PACKAGES[@]}")

# ==============================================================================
# CHECK FUNCTIONS  (return 0 = done, non-zero = not done)
# ==============================================================================

check_paru()              { cmd_exists paru; }
check_packages()          { pacman -Qq "${PACKAGES[@]}" &>/dev/null; }
check_amd_gpu()           { is_marked amd_gpu && grep -q 'amdgpu.dcdebugmask' /etc/kernel/cmdline 2>/dev/null; }
check_plymouth()          { is_marked plymouth && grep -q 'splash' /etc/kernel/cmdline 2>/dev/null && [[ -f /etc/dracut.conf.d/plymouth.conf && -f /etc/dracut.conf.d/30-monocraft.conf ]]; }
check_power_button()      { cmp -s "$CONFIG_DIR/system/logind/60-dots-power.conf" /etc/systemd/logind.conf.d/60-dots-power.conf && cmp -s "$CONFIG_DIR/system/sleep/60-dots-power.conf" /etc/systemd/sleep.conf.d/60-dots-power.conf && [[ $(systemctl show suspend.target -p LoadState --value) == loaded && $(systemctl show hibernate.target -p LoadState --value) == masked ]]; }
check_bluetooth()         { systemctl is-enabled bluetooth.service &>/dev/null; }
check_desktop_services()  { systemctl is-enabled power-profiles-daemon.service &>/dev/null; }
check_ctrl_backspace()    { grep -qF '"\C-H"' /etc/inputrc 2>/dev/null; }
check_monocraft()         { fc-list 2>/dev/null | grep -qi monocraft && [[ -f ${HOME}/.config/fontconfig/conf.d/99-monocraft.conf ]]; }
check_system_fonts()      { check_monocraft && [[ -f /etc/dracut.conf.d/30-monocraft.conf ]] && grep -q '^Theme=hexagon_hud_monocraft$' /etc/plymouth/plymouthd.conf && grep -q '^FONT=monocraft$' /etc/vconsole.conf; }
check_dns()               { grep -q '1.1.1.1' /etc/NetworkManager/conf.d/dns-servers.conf 2>/dev/null; }
check_wireguard()         { nmcli connection show 2>/dev/null | grep -qi wireguard; }
check_git_config()        { [[ -n "$(git config --global user.name 2>/dev/null)" ]]; }
check_gh_auth()           { gh auth status &>/dev/null; }
check_fingerprint()       { grep -q 'pam_fprintd' /etc/pam.d/sudo 2>/dev/null && cmp -s "$CONFIG_DIR/system/pam.d/dots-hyprlock" /etc/pam.d/dots-hyprlock && grep -Eq 'pam:module[[:space:]]*=[[:space:]]*dots-hyprlock' "$HOME/.config/hypr/hyprlock.conf" 2>/dev/null && fprintd-list "$USER" 2>/dev/null | grep -q 'right-index-finger'; }
check_ohmybash()          { [[ -f "${HOME}/.oh-my-bash/oh-my-bash.sh" ]]; }
check_bashrc()            { cmp -s "${CONFIG_DIR}/.bashrc" "${HOME}/.bashrc"; }
check_nemo_config()       { dconf read /org/nemo/preferences/bulk-rename-tool 2>/dev/null | grep -q 'bulky'; }
check_dotfiles()          { [[ -f "${HOME}/.vimrc" && -f "${HOME}/.tmux.conf" && -f "${HOME}/.bash_profile" && -f "${HOME}/.config/hypr/hyprland.lua" && -f "${HOME}/.config/waybar/config.jsonc" && -d "${HOME}/.config/alacritty" && -f "${HOME}/.config/Code - OSS/dots-profiles.json" && -f "${HOME}/.vscode-oss/argv.json" ]]; }
check_default_apps()      { default_apps check; }
check_nvm()               { (load_nvm && [[ "$(nvm version default)" != "N/A" ]]) &>/dev/null; }
check_vtop()              { (load_nvm && nvm use default && cmd_exists vtop) &>/dev/null; }
check_docker()            { systemctl is-enabled docker.service &>/dev/null; }
check_pcloud()            { cmd_exists pcloud; }
check_discord()           { [[ -f /etc/pacman.d/hooks/95-themeapply-discord.hook ]]; }
check_spotify()           { [[ -f /etc/pacman.d/hooks/95-themeapply-spotify.hook ]]; }
check_code()              { cmd_exists code && is_marked "code_config"; }
check_firefox()           { is_marked "firefox_setup"; }
check_steam()             { is_marked "steam_setup"; }
check_llama_cpp()         { systemctl --user is-enabled llama-cpp.service &>/dev/null; }

# ==============================================================================
# INSTALL FUNCTIONS
# ==============================================================================

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
    install_boot_hook
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
    print_header "Configuring suspend power policy"
    sudo bash "$SCRIPT_DIR/install.sh" --setup-power
    print_success "Power policy installed; takes effect after reboot"
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
    [[ $(fc-match -f '%{family}' Monocraft) == Monocraft ]] || {
        print_error 'Install Monocraft Nerd Font first'; return 1;
    }
    font_install "$CONFIG_DIR/.config/fontconfig/conf.d/99-monocraft.conf" "$HOME/.config/fontconfig/conf.d/99-monocraft.conf"
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
    for family in 'Monocraft Nerd Font' sans-serif serif monospace Arial 'Adwaita Sans'; do
        actual=$(fc-match -f '%{family}' "$family")
        [[ $actual == Monocraft ]] || { print_error "Font check failed: $family -> $actual"; return 1; }
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
    font_install "$CONFIG_DIR/.config/fontconfig/conf.d/99-monocraft.conf" "$conf"
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
    font_ini /etc/plymouth/plymouthd.conf Daemon DeviceScale 1
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
    print_step "Installing bundled font..."
    install -m0644 "$SCRIPT_DIR/assets/fonts/Monocraft-nerd-fonts-patched.ttc" \
        "${HOME}/.local/share/fonts/Monocraft-nerd-fonts-patched.ttc"
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
    sudo bash "$SCRIPT_DIR/install.sh" --install-lockscreen
    install -Dm0644 "$CONFIG_DIR/.config/hypr/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
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
    bash -n "${CONFIG_DIR}/.bashrc"
    if ! cmp -s "${CONFIG_DIR}/.bashrc" "${HOME}/.bashrc"; then
        if [[ -e "${HOME}/.bashrc" || -L "${HOME}/.bashrc" ]]; then
            backup=$(mktemp "${HOME}/.bashrc.backup.XXXXXX")
            cp -p "${HOME}/.bashrc" "$backup"
            print_step "Saved previous .bashrc to $backup"
        fi
        replacement=$(mktemp "${HOME}/.bashrc.install.XXXXXX")
        install -m 0644 "${CONFIG_DIR}/.bashrc" "$replacement"
        mv -f "$replacement" "${HOME}/.bashrc"
    fi
    print_success ".bashrc configured"
}

install_nemo_config() {
    print_header "Configuring Nemo"
    dconf load /org/nemo/ < "${CONFIG_DIR}/nemo_config"
    print_success "Nemo configuration loaded"
}

install_miku_assets() (
    local source="$SCRIPT_DIR/assets/miku"
    local data="${XDG_DATA_HOME:-$HOME/.local/share}/dots-miku" target scratch
    target="$data/prototypes/Miku"
    [[ -f $source/manifest.json ]] || { print_error 'Bundled Miku pack is missing'; return 1; }
    [[ ! -L $target && ( ! -e $target || -f $target/manifest.json ) ]] || {
        print_error "Inspect incomplete or symlinked Miku pack before replacing: $target"
        return 1
    }
    if [[ -d $target ]]; then
        print_step "Miku pack already installed; leaving it untouched: $target"
        return
    fi
    mkdir -p "$data/prototypes" || return
    scratch=$(mktemp -d "$data/install.XXXXXXXX") || return
    trap 'rm -rf -- "$scratch"' EXIT
    cp -R "$source" "$scratch/Miku" || return
    mv "$scratch/Miku" "$target" || return
    print_success "Miku pack installed: $target"
)

install_dotfiles() {
    print_header "Copying dotfiles"
    [[ ! -L $HOME/.config ]] || {
        print_error 'Refusing a symlinked .config parent; inspect it before copying dotfiles.'
        return 1
    }
    local config_dir path backup
    local -a config_paths=()
    for config_dir in \
        BetterDiscord alacritty fontconfig garden gtk-3.0 gtk-4.0 hypr keepassxc mako miku \
        opencode qt5ct qt6ct spicetify systemd themeapply uwsm visualizer waybar; do
        config_paths+=(".config/$config_dir")
    done
    config_paths+=(".config/Code - OSS" ".vscode-oss/argv.json")
    # Initial setup can replace defaults created by applications or /etc/skel.
    # Keep recovery data private and outside the configuration being replaced.
    backup=$(mktemp -d "$STATE_DIR/dotfiles-backup.XXXXXXXX")
    printf '%s\n' "${config_paths[@]}" .config/rofi .config/dots-utils \
        .oh-my-bash .vim .bash_profile .tmux.conf .vimrc > "$backup/paths.txt"
    while IFS= read -r path; do
        [[ ! -e $HOME/$path && ! -L $HOME/$path ]] || printf '%s\n' "$path"
    done < "$backup/paths.txt" > "$backup/existing.txt"
    tar -cpf "$backup/files.tar" -C "$HOME" -T "$backup/existing.txt"
    print_step "Recovery archive: $backup/files.tar"

    sudo bash "$SCRIPT_DIR/install.sh" --install-lockscreen

    print_step "Creating directories..."
    mkdir -p "${HOME}/.config"
    mkdir -p "${HOME}/Documents/BackUp/screenshots"
    mkdir -p "${HOME}/Documents/PC"

    print_step "Copying config directories..."
    tar -cpf - -C "$CONFIG_DIR" "${config_paths[@]}" .oh-my-bash .vim \
        | tar -xpf - --no-overwrite-dir -C "$HOME"
    local source_file relative
    while IFS= read -r -d '' source_file; do
        relative=${source_file#"${CONFIG_DIR}/"}
        [[ $relative != */settings.json || ! -f $HOME/$relative ]] || continue
        mkdir -p "$HOME/${relative%/*}"
        cp -p "$source_file" "$HOME/$relative"
    done < <(find "${CONFIG_DIR}/.config/rofi" -type f -print0)
    bash "$HOME/.config/rofi/icon-gen/generate.sh"

    print_step "Copying dotfiles..."
    cp -f \
        "${CONFIG_DIR}/.bash_profile" \
        "${CONFIG_DIR}/.tmux.conf" \
        "${CONFIG_DIR}/.vimrc" ~

    local sounds="${XDG_DATA_HOME:-$HOME/.local/share}/dots-sounds"
    install -d "$sounds"
    install -m0644 "$SCRIPT_DIR"/assets/sounds/* "$sounds/"

    systemctl --user daemon-reload
    bash "$HOME/.config/rofi/modi/time.sh" reconcile
    print_success "Dotfiles copied"
    bash "${SCRIPT_DIR}/scripts/build-miku-renderer.sh"
    install_miku_assets
}

# One table drives both installation and completion checks. These are Arch's
# package desktop IDs, including code and spotify-launcher.
default_apps() {
    local action=$1 desktop mime row directory found
    local -a types directories
    IFS=: read -ra directories <<< "${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    while read -r desktop row; do
        found=0
        for directory in "${directories[@]}"; do
            if [[ -f $directory/applications/$desktop ]]; then found=1; break; fi
        done
        if (( ! found )); then
            print_error "Missing application handler: $desktop. Install all packages first."
            return 1
        fi
        read -ra types <<< "$row"
        if [[ $action == install ]]; then
            xdg-mime default "$desktop" "${types[@]}" || return
        else
            for mime in "${types[@]}"; do
                [[ $(xdg-mime query default "$mime") == "$desktop" ]] || return 1
            done
        fi
    done <<'DEFAULTS'
code-oss.desktop text/plain text/markdown application/json application/xml text/xml application/yaml text/yaml application/x-yaml application/x-shellscript text/x-shellscript text/css text/javascript application/javascript text/x-python application/x-code-workspace application/x-code-oss-workspace
code-oss-url-handler.desktop x-scheme-handler/code-oss
firefox.desktop text/html application/xhtml+xml application/pdf x-scheme-handler/http x-scheme-handler/https
vlc.desktop video/mp4 video/x-matroska video/webm video/x-msvideo video/quicktime video/mpeg audio/mpeg audio/flac audio/ogg audio/opus audio/x-wav audio/wav audio/aac audio/mp4
gimp.desktop image/png image/jpeg image/gif image/webp image/tiff image/bmp image/svg+xml
nemo.desktop inode/directory
discord.desktop x-scheme-handler/discord
spotify-launcher.desktop x-scheme-handler/spotify
DEFAULTS
}

install_default_apps() {
    print_header "Setting default applications"
    default_apps install || return
    check_default_apps || return
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

install_app_theme() {
    local app=$1 package=$1 user hook
    case $app in
        discord|spotify) ;;
        *) print_error "Unsupported app theme: $app (use discord or spotify)"; return 2 ;;
    esac
    [[ $app != spotify ]] || package=spotify-launcher
    user=$(id -un)
    [[ $user =~ ^[a-z_][a-z0-9_-]*$ ]] || {
        print_error 'Unsupported username for the application theme hook.'
        return 1
    }
    [[ -f $HOME/.config/themeapply/apply.sh &&
       -f $HOME/.config/systemd/user/themeapply@.service ]] || {
        print_error 'Run Copy dotfiles before application theme setup.'
        return 1
    }
    hook="$STATE_DIR/themeapply-$app.hook"
    sed -e "s/@APP@/$app/g" -e "s/@PACKAGE@/$package/g" -e "s/@USER@/$user/g" \
        "$CONFIG_DIR/system/pacman-hooks/95-themeapply.hook" > "$hook"
    sudo install -Dm0644 "$hook" "/etc/pacman.d/hooks/95-themeapply-$app.hook"
    systemctl --user daemon-reload
    systemctl --user start "themeapply@$app.service"
}

install_discord() {
    print_header "Setting up Discord + BetterDiscord"
    local settings="$HOME/.config/BetterDiscord/data/stable/themes.json" temporary backup
    mkdir -p "${settings%/*}"
    temporary=$(mktemp "${settings}.XXXXXXXX")
    if [[ -f $settings ]]; then
        backup=$(mktemp "$STATE_DIR/discord-themes.XXXXXXXX.json")
        cp -p "$settings" "$backup"
        jq '.["Neutron Nova"] = true' "$settings" > "$temporary"
    else
        printf '%s\n' '{"Neutron Nova": true}' > "$temporary"
    fi
    mv "$temporary" "$settings"
    # First launch downloads the user-owned app before BetterDiscord can patch it.
    if ! pgrep -u "$UID" -x '[Dd]iscord' >/dev/null; then
        discord >/dev/null 2>&1 &
    fi
    read -rp '  Wait for Discord to finish opening, then press Enter to apply its theme...'
    install_app_theme discord
    print_success "Automatic BetterDiscord setup enabled; account login remains yours"
}

install_spotify() {
    print_header "Setting up Spotify + Spicetify"
    install_app_theme spotify || return
    # The first normal launch creates Spotify's prefs; no scripted account login.
    if ! pgrep -u "$UID" -x spotify >/dev/null; then
        spotify-launcher >/dev/null 2>&1 &
    fi
    print_success "Automatic Spicetify setup enabled with the desktop Ziro theme"
}

install_code() {
    print_header "Setting up Code"
    python3 "$SCRIPT_DIR/backup-vscode.py" --install --config-dir "$HOME" || return
    mark_done "code_config"
    print_success "Code configured"
}

install_firefox() {
    print_header "Setting up Firefox"
    firefox > /dev/null 2>&1 &
    read -p "  Log in Firefox
  Sync settings
  Import vimium-options.json and bonjourr.json from ~/dots/config/
  Fix New Tab Override (https://online.bonjourr.fr/)
  Fix persistant tabs
  Fix bookmarks layout
  Add cookies exceptions (google,github,bonjourr,...)
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
    cp -f "${CONFIG_DIR}/.config/systemd/user/llama-cpp.service" \
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
    "Install paru"
    "Install all packages"
    "AMD GPU fix (Framework)"
    "Configure Plymouth"
    "Configure suspend power policy"
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
    "Set up Spotify + Spicetify"
    "Set up Code"
    "Set up Firefox"
    "Set up Steam"
    "Configure WireGuard VPN"
)

TASK_CHECKS=(
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
    check_code
    check_firefox
    check_steam
    check_wireguard
)

TASK_INSTALLS=(
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
    install_code
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
TUI_VISIBLE_ROWS=0
TUI_LAST_MSG=""

refresh_status() {
    local label="${1:-Checking installation status}" i
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

tui_size() {
    local term_rows
    term_rows=$(tput lines 2>/dev/null) || term_rows=24
    [[ $term_rows =~ ^[1-9][0-9]*$ ]] || term_rows=24
    # Five header lines, four footer lines, and one spare cursor line.
    TUI_VISIBLE_ROWS=$(( term_rows - 10 ))
    (( TASK_COUNT <= TUI_VISIBLE_ROWS )) || TUI_VISIBLE_ROWS=$(( TUI_VISIBLE_ROWS - 1 ))
    (( TUI_VISIBLE_ROWS <= TASK_COUNT )) || TUI_VISIBLE_ROWS=$TASK_COUNT
    if (( TUI_VISIBLE_ROWS < 1 )); then TUI_VISIBLE_ROWS=0; return; fi
    (( TUI_SCROLL <= TASK_COUNT - TUI_VISIBLE_ROWS )) || TUI_SCROLL=$(( TASK_COUNT - TUI_VISIBLE_ROWS ))
    (( TUI_SCROLL <= TUI_CURSOR )) || TUI_SCROLL=$TUI_CURSOR
    (( TUI_CURSOR < TUI_SCROLL + TUI_VISIBLE_ROWS )) || TUI_SCROLL=$(( TUI_CURSOR - TUI_VISIBLE_ROWS + 1 ))
}

draw_tui() {
    tui_size
    if (( TUI_VISIBLE_ROWS == 0 )); then
        tput clear
        printf 'Resize terminal (12+ rows); Q quits.'
        return
    fi

    local done_count=0 selected_count=0 i
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
    local i
    installer_windows start || return
    export DOTS_INSTALLER_WINDOWS_ACTIVE=1
    trap 'installer_windows stop; tput cnorm; tput clear' EXIT
    for (( i=0; i<TASK_COUNT; i++ )); do
        TASK_SELECTED[$i]=0
    done

    refresh_status

    trap 'draw_tui' WINCH

    tput civis  # hide cursor

    while true; do
        draw_tui
        TUI_LAST_MSG=""

        # Read key input
        local key seq1 seq2
        IFS= read -rsn1 key || continue
        if (( TUI_VISIBLE_ROWS == 0 )); then
            [[ ${key,,} != q ]] || break
            continue
        fi

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

            # Closing an app can resize this terminal. Do not redraw the menu
            # over task prompts or interrupt the selected-task loop.
            trap ':' WINCH
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
            trap 'draw_tui' WINCH
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
                if [[ ${DOTS_INSTALLER_WINDOWS_ACTIVE:-0} != 1 ]]; then
                    installer_windows start
                    trap 'installer_windows stop' EXIT
                fi
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

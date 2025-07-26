#!/bin/bash

# gpg --keyserver-options auto-key-retrieve --verify archlinux.iso.sig

# sudo usbimager

# extra packages: git vim firefox less

# --------------------

# fetch dots
cd ~
git clone https://github.com/V1K1NGbg/dots.git

# vim install.sh

# enable multilib for steam
sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

# update system
sudo pacman -Syu

# install paru
sudo pacman -S --needed base-devel
git clone https://aur.archlinux.org/paru-git.git
cd paru-git
makepkg -si
cd ..
sudo rm -r paru-git

# update awesome
sudo pacman -Rs awesome
paru -S awesome-git

# install packages
paru -S acpi alacritty alsa-utils ani-cli arandr autorandr bash-completion blueman bluez bluez-utils baobab bulky capitaine-cursors cowsay cpupower-gui-git curl dangerzone-bin discord docker dracut fd firefox flameshot fzf gimp git github-cli glava gnome-disk-utility highlight htop i3lock-color jdk21-openjdk jdk8-openjdk keepassxc lazygit less libconfig lobster-git lolcat man-db man-pages meld moonlight-qt nano nemo nemo-compare nemo-fileroller nemo-preview neofetch network-manager-applet noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra parcellite pasystray pavucontrol pcloud-drive plymouth plymouth-theme-hexagon-hud-git prismlauncher qt6-svg ranger redshift rofi rofi-calc ruby-fusuma sof-firmware spotify-launcher steam sunshine tmux tree unclutter unzip usbimager uthash vim visual-studio-code-bin vlc wget xdotool xorg-xinput xss-lock zip

# auto login - create systemd drop-in file
sudo systemctl edit getty@tty1.service --drop-in=autologin --stdin <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin victor %I %TERM
EOF

# auto start awesome
echo 'if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
        exec startx
fi' >> ~/.bash_profile

# picom
git clone https://github.com/pijulius/picom.git
cd picom
meson setup --buildtype=release build
ninja -C build
ninja -C build install
cd ..
sudo rm -r picom/

# plymouth
sudo sed -i 's/^options .*/& quiet splash/' /boot/loader/entries/$(ls /boot/loader/entries/ | head -1)
sudo sed -i 's/HOOKS=(\([^)]*\)encrypt\([^)]*\))/HOOKS=(\1plymouth encrypt\2)/' /etc/mkinitcpio.conf
sudo dracut
sudo plymouth-set-default-theme -R hexagon_hud

# git
mkdir -p ~/Documents/GitHub
git config --global user.name "V1K1NGbg"
git config --global user.email "victor@ilchev.com"
# git config --global pull.rebase true
gh auth login

# enable bluetooth
systemctl enable bluetooth.service
systemctl start bluetooth.service

# install nvm (link from: https://github.com/nvm-sh/nvm/)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install node

# vtop
sudo npm install -g vtop

# install oh-my-bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"
exit

# # !!! carefull make new fzf setup
# # install fzf-completion
# git clone https://github.com/lincheney/fzf-tab-completion

# !!! ONLY FON NVIDIA GPU'S (NOT SUPPORTED)!!!
# # install nvidia drivers (https://wiki.archlinux.org/title/NVIDIA)
# paru -S nvidia-open nvidia-utils nvidia-settings
# # install requirements for gpu enabling/disabling gpu
# paru -S envycontrol
# # change to integrated
# sudo envycontrol -s integrated

# enable tap clicking, natural scrolling and double tap
sudo sed -i '/Section "InputClass"/,/EndSection/ {
        /Identifier.*touchpad/,/EndSection/ {
        /Driver "libinput"/a\
        Option "Tapping" "on"\
        Option "NaturalScrolling" "true"\
        Option "ClickMethod" "clickfinger"
        }
}' /usr/share/X11/xorg.conf.d/40-libinput.conf

# enable bg layout
sudo sed -i '/Section "InputClass"/,/EndSection/ {
        /Identifier.*system-keyboard/,/EndSection/ {
        s/Option "XkbLayout".*$/Option "XkbLayout" "us,bg"/
        /Option "XkbLayout"/a\
        Option "XkbVariant" ",bas_phonetic"
        }
}' /etc/X11/xorg.conf.d/00-keyboard.conf

# Monocraft (https://github.com/IdreesInc/Monocraft/releases/download/v4.1/Monocraft-nerd-fonts-patched.ttc)
mkdir -p ~/.local/share/fonts
curl -L -o ~/.local/share/fonts/Monocraft-nerd-fonts-patched.ttc https://github.com/IdreesInc/Monocraft/releases/download/v4.1/Monocraft-nerd-fonts-patched.ttc
fc-cache
fc-list | grep Monocraft 

# # cursor !OLD!
# vim .Xresources
# #Xcursor.theme: capitaine-cursors
# #Xcursor.size: 24
# # RESTART XORG

# # gtk !OLD!
# vim ~/.config/gtk-3.0/settings.ini
# #gtk-application-prefer-dark-theme=1

# fusuma
sudo gpasswd -a $USER input
newgrp input
mkdir -p ~/.config/fusuma

# static dns
sudo tee /etc/NetworkManager/conf.d/dns-servers.conf > /dev/null <<EOF
[global-dns-domain-*]
servers=1.1.1.1,1.0.0.1
EOF

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

cd dots

# copy nemo
# # export
# dconf dump /org/nemo/ > nemo_config
#import
dconf load /org/nemo/ < nemo_config

# copy awesome config
mkdir -p ~/.config/awesome/

# # copy gnome-terminal !OLD!
# # export
# dconf dump /org/gnome/terminal/ > gnome_terminal_settings.txt
# #copy contents (https://gist.github.com/V1K1NGbg/28d6098e4013ca7b904453cf96c671cd)
# #import
# dconf load /org/gnome/terminal/ < gnome_terminal_settings.txt
# rm gnome_terminal_settings.txt

# alacritty
mkdir -p ~/.config/alacritty/

# vim
mkdir -p ~/.vim/colors/

# flameshot
mkdir -p ~/Documents/BackUp/screenshots

# pcloud folders
mkdir -p ~/Documents/BackUp
mkdir -p ~/Documents/PC

# docker
sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo usermod -aG docker $USER
newgrp docker

# wireguard
read -e -p "Enter path to WireGuard config file: " wg_config_path
wg_config_name=$(basename "$wg_config_path" .conf)

nmcli connection import type wireguard file "$wg_config_path"
nmcli connection modify "$wg_config_name" connection.autoconnect no

# # cloudflare-warp !OLD!
# sudo systemctl enable warp-svc
# sudo systemctl start warp-svc
# warp-cli registration new

# bashrc
grep -v "source" ~/.bashrc > tmpfile && mv -f tmpfile ~/.bashrc
cat .bashrc >> ~/.bashrc

# for ctrl+backspace in terminal
echo '"\C-H":"\C-W"' | sudo tee -a /etc/inputrc

# copy configs
yes | cp -rf .config/ ~
yes | cp -rf .oh-my-bash/ ~
yes | cp -rf .vim/ ~
yes | cp -rf .screenlayout/ ~
yes | cp -f .tmux.conf .vimrc .Xresources i3lock.sh ~
read -e -p "Awesome const path: " awesome_const_path
yes | cp -f "$awesome_const_path" ~/.config/awesome/

# i3lock
chmod +x ~/i3lock.sh

# default applications
xdg-mime default xdg-open.desktop *
xdg-mime default code.desktop text/*
xdg-mime default firefox.desktop text/html
xdg-mime default firefox.desktop application/pdf
xdg-mime default vlc.desktop video/*
xdg-mime default vlc.desktop audio/*
xdg-mime default gimp.desktop image/*
xdg-mime default nemo.desktop inode/*

# discord
discord &
read -p "Log in Discord and press Enter to continue..."
read -p "Downloading BetterDiscord installer and then press Enter to continue..."
xdg-open https://betterdiscord.app/ &
curl -L -o ~/Downloads/BetterDiscord-Linux.AppImage https://github.com/BetterDiscord/Installer/releases/latest/download/BetterDiscord-Linux.AppImage
chmod +x ~/Downloads/BetterDiscord-Linux.AppImage
~/Downloads/BetterDiscord-Linux.AppImage &
read -p "Set up BetterDiscord and press Enter to continue..."
killall Discord
killall Discord

# pcloud
pcloud &
read -p "Log in pCloud and press Enter to continue..."
read -p "Sync ~/Documents/PC <-> pCloudDrive/PC, Backup ~/Documents/BackUp and press Enter to continue..."

# vscode
code &
read -p "Log in VSCode, sync settings and press Enter to continue..."

# firefox
firefox &
read -p "Log in Firefox
Sync settings
Import vimium and bonjourr configs
Fix bookmarks layout
Set duck duck go as default search engine
Add cookies exceptions (google,github,uni...) 
and finally press Enter to continue..."


# steam
steam &
read -p "Log in Steam and press Enter to continue..."

# spotify
spotify &
read -p "Log in Spotify and press Enter to continue..."

# restart
read -p "Restart system to apply all changes and press Enter to continue..."
reboot

# # docker containers !OLD!
# cd dots

# mkdir ~/docker_data/pihole/etc-pihole
# mkdir ~/docker_data/pihole/etc-dnsmasq.d
# mkdir ~/docker_data/portainer

# ./docker_setup.sh

#!!! GO BACK TO FINISH FZF SETUP

#--------------------------------------------

# phone integration
# villager sounds

#--------------------------------------------

# usefull commands:

# list all installed packages
paru -Qqen > pkglist.txt

# change brightness
xrandr --output eDP-1 --brightness 0.5

# verify signature
gpg --keyserver-options auto-key-retrieve --verify archlinux.iso.sig

# redshift
redshift -P -O 4500
redshift -x
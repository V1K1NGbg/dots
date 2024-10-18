#!/bin/bash

# sudo usbimager

# update
sudo pacman -Syu

# install paru dependencies
sudo pacman -S git
# install paru
sudo pacman -S --needed base-devel
git clone https://aur.archlinux.org/paru-git.git
cd paru-git
makepkg -si
cd ..
sudo rm -r paru

# remove awesome
sudo pacman -Rs awesome
# install the latest
paru -S awesome-git

# install packages
paru -S acpi alacritty alsa-utils arandr autorandr bash-completi1on blueman bluez bluez-utils capitaine-cursors cowsay cpupower-gui-git curl discord docker dracut fd firefox flameshot fzf gimp git github-cli glava gnome-boxes gnome-disk-utility htop i3lock-color jdk21-openjdk jdk8-openjdk keepassxc less lolcat man-db man-pages nano nemo neofetch network-manager-applet obs-studio parsec-bin pasystray pavucontrol pcloud-drive plymouth plymouth-theme-hexagon-hud-git prismlauncher ranger remmina rofi rofi-calc spotify-launcher tmux tree qt6-svg unzip usbimager-x11 vim visual-studio-code-bin wget xdotool xss-lock zip

# pcom
git clone https://github.com/pijulius/picom.git
cd picom
meson setup --buildtype=release build
ninja -C build
ninja -C build install

# plymouth
sudo vim /boot/loader/entries/{TAB}.conf
#options ... quiet splash
sudo vim /etc/mkinitcpio.conf
#HOOKS=(... plymouth ...) !!!BEFORE ENCRYPT OR SOME SORT OF CRYPT!!!
sudo dracut
# set theme
sudo plymouth-set-default-theme -R hexagon_hud

# git
git config --global user.name "V1K1NGbg"
git config --global user.email "victor@ilchev.com"
git config pull.rebase true
gh auth login

# pcloud
# sign in (Google + Auth)
# Backup ~/Documents/BackUp
# Sync ~/Documents/PC <-> pCloudDrive/PC

# enable bluetooth
systemctl enable bluetooth.service
systemctl start bluetooth.service

# install nvm (link from: https://github.com/nvm-sh/nvm/)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
# source
source ~/.bashrc
# install node and npm
nvm install node

# install oh-my-bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"

# install nvidia drivers (https://wiki.archlinux.org/title/NVIDIA)
paru -S nvidia-open nvidia-utils nvidia-settings
# install requirements for gpu enabling/disabling gpu
paru -S envycontrol
# change to integrated
sudo envycontrol -s integrated


# enable tap clicking, natural scrolling and double tap
# in (/usr/share/X11/xorg.conf.d/40-libinput.conf)
# Section "InputClass"
#     Identifier "... touchpad ..."
#     ...
#     Driver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "ClickMethod" "clickfinger"
# EndSection

# enable bg layout
# in (/etc/X11/xorg.conf.d/00-keyboard.conf)
# Section "InputClass"
#         Identifier "system-keyboard"
#         MatchIsKeyboard "on"
        Option "XkbLayout" "us,bg"
#         Option "XkbModel" "pc105+inet"
        Option "XkbVariant" ",bas_phonetic"
#         Option "XkbOptions" "terminate:ctrl_alt_bksp"
# EndSection

# Monocraft (https://github.com/IdreesInc/Monocraft/releases)
# create ~/.local/share/fonts
mkdir -p ~/.local/share/fonts
# add Monocraft-nerd-fonts-patched.ttc to the folder
mv ~/Downloads/Monocraft-nerd-fonts-patched.ttc ~/.local/share/fonts/
# reload the fonts
fc-cache
# check
fc-list | grep Monocraft # check

# # cursor
# vim .Xresources
# #Xcursor.theme: capitaine-cursors
# #Xcursor.size: 24
# # RESTART XORG

# # gtk
# vim ~/.config/gtk-3.0/settings.ini
# #gtk-application-prefer-dark-theme=1


# fusuma
sudo gem install fusuma #(?)
sudo gpasswd -a $USER input
newgrp input
mkdir -p ~/.config/fusuma

# static dns
sudo vim /etc/NetworkManager/conf.d/dns-servers.conf
# [global-dns-domain-*]
# servers=::1,1.1.1.1

# # feh
# feh --bg-scale ${imageurl}

# fix monitoor setup
# arandr to setup ONLY LAPTOP
autorandr --save laptop
autorandr --default laptop
# arandr to setup EXTEND LAPTOP
autorandr --save laptop_external
# # arandr to setup DUPLICATE LAPTOP
# autorandr --save laptop_duplicate

# generate ranger config
ranger --copy-config=all
vim .config/ranger/rc.conf
# set show_hidden true
# set colorscheme jungle

# copy nemo
# # export
# dconf dump /org/nemo/ > nemo_settings.txt

#import
dconf load /org/nemo/ < nemo_settings.txt

# copy awesome config
mkdir -p ~/.config/awesome/

# # copy gnome-terminal
# # export
# dconf dump /org/gnome/terminal/ > gnome_terminal_settings.txt
# #copy contents (https://gist.github.com/V1K1NGbg/28d6098e4013ca7b904453cf96c671cd)
# #import
# dconf load /org/gnome/terminal/ < gnome_terminal_settings.txt
# rm gnome_terminal_settings.txt

# alacritty
mkdir -p ~/.config/alacritty/
vim ~/.config/alacritty/alacritty.toml

# vim
mkdir -p .vim/colors/

# i3lock
chmod +x ~/i3lock.sh

# firefox
# bookmark for calendar and mail

# docker

# discord
# download https://betterdiscord.app/
cd Downloads
chmod +x BetterDiscord-Linux.AppImage
./BetterDiscord-Linux.AppImage

# wireguard
nmcli connection import type wireguard file "/path/to/wg0.conf" # (?)

# solo key
# phone integration

#--------------------------------------------

# usefull commands:

# list all installed packages
paru -Qqen > pkglist.txt

# change brightness
xrandr --output eDP-1 --brightness 0.5
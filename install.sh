#!/bin/bash

# sudo usbimager

# extra packages: git vim firefox

git clone https://github.com/V1K1NGbg/dots.git

# vim install.sh

# update
sudo pacman -Syu

# install paru
sudo pacman -S --needed base-devel
git clone https://aur.archlinux.org/paru-git.git
cd paru-git
makepkg -si
cd ..
sudo rm -r paru-git

# remove awesome
sudo pacman -Rs awesome
# install the latest
paru -S awesome-git

# install packages
paru -S acpi alacritty alsa-utils arandr autorandr bash-completion blueman bluez bluez-utils baobab bottles bulky capitaine-cursors cowsay cpupower-gui-git curl discord docker dracut fd firefox flameshot fzf gimp git github-cli glava gnome-disk-utility htop i3lock-color jdk21-openjdk jdk8-openjdk keepassxc less lolcat man-db man-pages nano nemo nemo-compare nemo-fileroller nemo-preview neofetch network-manager-applet pasystray pavucontrol pcloud-drive plymouth plymouth-theme-hexagon-hud-git prismlauncher qt6-svg ranger rofi rofi-calc rpi-imager ruby-fusuma sof-firmware spotify-launcher tmux tree unclutter unzip uthash vim visual-studio-code-bin vlc wget xdotool xorg-xinput xss-lock zip

# auto login
sudo vim /etc/systemd/system/getty.target.wants/getty\@tty1.service

#ExecStart=-/sbin/agetty -o '-p -- \\u' --noclear - $TERM
ExecStart=-/sbin/agetty -a victor - $TERM

# add to ~/.bash_profile
vim ~/.bash_profile

if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
   exec startx
fi

# pcom
git clone https://github.com/pijulius/picom.git
cd picom
meson setup --buildtype=release build
ninja -C build
ninja -C build install
cd ..
sudo rm -r picom/

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
git config --global pull.rebase true
gh auth login
mkdir -p ~/Documents/GitHub

# pcloud
pcloud
# sign in (Google + Auth)
mkdir -p ~/Documents/BackUp
mkdir -p ~/Documents/PC
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

# vtop
sudo npm install -g vtop

# install oh-my-bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"

# !!! ONLY FON NVIDIA GPU'S !!!

# install nvidia drivers (https://wiki.archlinux.org/title/NVIDIA)
paru -S nvidia-open nvidia-utils nvidia-settings
# install requirements for gpu enabling/disabling gpu
paru -S envycontrol
# change to integrated
sudo envycontrol -s integrated

# enable tap clicking, natural scrolling and double tap
# in (/usr/share/X11/xorg.conf.d/40-libinput.conf)

sudo vim /usr/share/X11/xorg.conf.d/40-libinput.conf

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

sudo vim /etc/X11/xorg.conf.d/00-keyboard.conf

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
fc-list | grep Monocraft 

# # cursor
# vim .Xresources
# #Xcursor.theme: capitaine-cursors
# #Xcursor.size: 24
# # RESTART XORG

# # gtk
# vim ~/.config/gtk-3.0/settings.ini
# #gtk-application-prefer-dark-theme=1

# fusuma
sudo gpasswd -a $USER input
newgrp input
mkdir -p ~/.config/fusuma

# static dns
sudo vim /etc/NetworkManager/conf.d/dns-servers.conf
# [global-dns-domain-*]
# servers=::1,1.1.1.1

# # feh
# feh --bg-scale ${imageurl}

# # fix monitoor setup
# # arandr to setup ONLY LAPTOP
# autorandr --save laptop
# autorandr --default laptop
# # arandr to setup EXTEND LAPTOP
# autorandr --save laptop_external
# # # arandr to setup DUPLICATE LAPTOP
# # autorandr --save laptop_duplicate

# # generate ranger config
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

# # copy gnome-terminal
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

# docker
sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo usermod -aG docker $USER
newgrp docker

# wireguard
nmcli connection import type wireguard file "/path/to/WG.conf" # !!! CHANGE PATH !!!
nmcli connection modify WG connection.autoconnect no # !!! CHANGE NAME !!!

# bashrc
# to remove the sourcing of the theme in oh my bash
grep -v "source" ~/.bashrc > tmpfile && mv -f tmpfile ~/.bashrc
cat .bashrc >> ~/.bashrc

# copy configs
yes | cp -rf .config/ ~
yes | cp -rf .oh-my-bash/ ~
yes | cp -rf .vim/ ~
yes | cp -rf .screenlayout/ ~

yes | cp -f .tmux.conf .vimrc .Xresources i3lock.sh ~
yes | cp -f /path/to/const.lua ~/.config/awesome/ # !!! CHANGE PATH !!!

# discord
discord
# start discord and login to install the propper files
# download https://betterdiscord.app/
chmod +x ~/Downloads/BetterDiscord-Linux.AppImage
~/Downloads/BetterDiscord-Linux.AppImage
# sign in

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

# RESTART
reboot

# vscode
# sign in

# firefox
# sign in
# import VIMIUM and Bonjourr
# bookmarks fix layout
# cookies exceptions (uni,google,github)

# spotify
# sign in

# phone integration
# villager sounds

#--------------------------------------------

# usefull commands:

# list all installed packages
paru -Qqen > pkglist.txt

# change brightness
xrandr --output eDP-1 --brightness 0.5

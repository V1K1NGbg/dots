#!/usr/bin/env bash

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$repository_root" || exit 1

# nemo
dconf dump /org/nemo/ > nemo_config

# .config
cp -rf ~/.config/alacritty/ .config/ 2>/dev/null
cp -rf ~/.config/flameshot/ .config/ 2>/dev/null
cp -rf ~/.config/fusuma/ .config/ 2>/dev/null
cp -rf ~/.config/glava/ .config/ 2>/dev/null
cp -rf ~/.config/gtk-3.0/ .config/ 2>/dev/null
cp -rf ~/.config/keepassxc/ .config/ 2>/dev/null
cp -rf ~/.config/rofi/ .config/ 2>/dev/null
# cp -rf ~/.config/BetterDiscord/ .config/ 2>/dev/null
# cp -rf ~/.config/spicetify/ .config/ 2>/dev/null

# files
cp ~/.bash_profile . 2>/dev/null
cp ~/.bashrc . 2>/dev/null
cp ~/.tmux.conf . 2>/dev/null
cp ~/.vimrc . 2>/dev/null
cp ~/.Xresources . 2>/dev/null

# vim
cp -rf ~/.vim/ .

# copyq
copyq eval 'exportData()' > copyq.cpq 2>/dev/null

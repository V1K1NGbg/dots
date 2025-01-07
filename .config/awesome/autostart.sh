#!/bin/sh

start() {
  if ! pgrep -f "$1" ;
  then
    "$@"&
  fi
}

# start discord --start-minimized
start code
start firefox
start discord
start alacritty
start nemo
start spotify-launcher
start keepassxc

start nm-applet
start blueman-applet
start pcloud
start flameshot
start pasystray

start picom -b
start fusuma -d
start xss-lock ~/i3lock.sh
# start glava -d

start unclutter -idle 1 -jitter 2 -root &
~/.bashrc
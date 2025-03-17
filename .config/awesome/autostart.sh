#!/bin/sh

start() {
  if ! pgrep -f "$1" ;
  then
    "$@"&
  fi
  sleep 0.5
}

start nm-applet
start blueman-applet
start pcloud
start flameshot
start pasystray
start parcellite

start picom -b
start fusuma -d
start xss-lock ~/i3lock.sh
# start glava -d

# start discord --start-minimized
start firefox
start discord
start alacritty
start nemo
start spotify-launcher
start keepassxc
start code

start unclutter -idle 1 -jitter 2 -root &
~/.bashrc
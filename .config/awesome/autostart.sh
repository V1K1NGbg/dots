#!/bin/sh

start() {
  if ! pgrep -f "$1" ;
  then
    "$@"&
  fi
}

start discord --start-minimized
start alacritty
start nemo
start spotify-launcher
start keepassxc
start code
start firefox

start nm-applet
start blueman-applet
start pcloud
start flameshot
start pasystray

start picom -b
start fusuma -d
start xss-lock ~/i3lock.sh
# start glava -d
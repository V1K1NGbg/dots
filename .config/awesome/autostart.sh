#!/bin/sh

start() {
  if ! pgrep -f "$1" ;
  then
    "$@"&
  fi
}

start firefox
start code
start alacritty
start discord
start nemo
start spotify-launcher

start nm-applet
start blueman-applet
start pcloud
start flameshot
start pasystray

start picom -b
start fusuma -d
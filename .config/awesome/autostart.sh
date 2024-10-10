#!/bin/sh

start() {
  if ! pgrep -f "$1" ;
  then
    "$@"&
  fi
}

start nm-applet
start blueman-applet
start pcloud
start flameshot
start picom -b
start code
start alacritty
start discord
start nemo
start spotify-launcher
start firefox
start pasystray
start fusuma -d
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
start xss-lock -l --session=${XDG_SESSION_ID} ~/i3lock.sh
# start glava -d
redshift -P -O 4500

# start discord --start-minimized
start spotify-launcher
start firefox
start discord
start alacritty
start nemo
# start keepassxc
start code

start unclutter -idle 1 -jitter 2 -root &
~/.bashrc
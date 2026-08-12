#!/bin/sh

start_once() {
  if ! pgrep -u "${USER}" -f "(^|/)${1}([[:space:]]|$)" >/dev/null 2>&1; then
    "$@" &
  fi
  sleep 0.5
}

start_once nm-applet
start_once blueman-applet
start_once pcloud
start_once flameshot
start_once pasystray
start_once copyq

start_once picom -b
start_once fusuma -d
start_once xss-lock -l --session="${XDG_SESSION_ID}" "${HOME}/i3lock.sh"
# start_once glava -d
start_once redshift -P -O 4500

# Keep the original daily-driver startup behavior on the stable profile.
start_once spotify
start_once firefox
start_once discord
start_once alacritty
start_once nemo
# start_once keepassxc
start_once code

start_once unclutter -idle 1 -jitter 2 -root

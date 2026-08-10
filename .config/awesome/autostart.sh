#!/bin/sh

# Background session services only. Interactive applications belong in the
# launcher and must not reopen every time Awesome is restarted.
start_once() {
  process_name=$1
  shift
  command -v "$1" >/dev/null 2>&1 || return 0
  if ! pgrep -u "$(id -u)" -x "$process_name" >/dev/null 2>&1; then
    "$@" >/dev/null 2>&1 &
  fi
}

start_once nm-applet nm-applet
start_once blueman-applet blueman-applet
start_once pcloud pcloud
start_once flameshot flameshot
start_once pasystray pasystray
start_once copyq copyq
start_once picom picom -b
start_once fusuma fusuma -d
start_once xss-lock xss-lock -l --session="${XDG_SESSION_ID:-}" "$HOME/i3lock.sh"
start_once unclutter unclutter -idle 1 -jitter 2 -root

command -v redshift >/dev/null 2>&1 && redshift -P -O 4500

#!/usr/bin/env bash

set -u

spawn() {
    "$@" >/dev/null 2>&1 &
}

spawnsl() {
    spawn "$@"
    sleep 1
}

dbus-update-activation-environment --systemd \
    WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
systemctl --user import-environment \
    WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
systemctl --user start \
    hypridle.service \
    hyprpolkitagent.service \
    hyprsunset.service \
    cava-wallpaper.service \
    nemo-settings.service || true

spawn waybar
spawn nm-applet --indicator
spawn blueman-applet
spawn pcloud
spawn mako
spawn wl-paste --type text --watch cliphist store
spawn wl-paste --type image --watch cliphist store

spawnsl spotify
spawnsl Discord
spawnsl nemo
spawnsl alacritty
spawnsl code
spawnsl firefox

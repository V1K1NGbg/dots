#!/usr/bin/env bash

set -u

# Serialize invocations and avoid launching duplicate tray/clipboard services.
exec 9>"${XDG_RUNTIME_DIR:?}/dots-autostart.lock"
flock -n 9 || exit 0

spawn() {
    if [[ $1 == wl-paste ]]; then
        pgrep -u "$UID" -f -- "(^|/)$*([[:space:]]|$)" >/dev/null && return
    else
        pgrep -u "$UID" -x -- "${1##*/}" >/dev/null && return
    fi
    "$@" 9>&- >/dev/null 2>&1 &
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
    hyprsunset.service || true

if ! pgrep -u "$UID" -x waybar >/dev/null; then
    systemd-cat --identifier=dots-waybar waybar 9>&- &
    (
        sleep 1
        hyprctl dispatch 'function() dots.bar_restarted() end'
    ) 9>&- &
fi
spawn nm-applet --indicator
spawn blueman-applet
spawn pcloud
spawn mako
spawn wl-paste --type text --watch cliphist store
spawn wl-paste --type image --watch cliphist store

spawnsl discord
spawnsl spotify
spawnsl alacritty
spawnsl nemo
spawnsl code
spawnsl firefox

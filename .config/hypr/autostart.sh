#!/usr/bin/env bash

set -u

# Serialize invocations and avoid launching duplicate tray/clipboard services.
exec 9>"${XDG_RUNTIME_DIR:?}/dots-autostart.lock"
flock -n 9 || exit 0

spawn() {
    if [[ $1 == pcloud ]]; then
        # AppRun becomes pcloud.bin. A second launch opens its window even when
        # pCloud's saved "start minimized" preference is enabled.
        pgrep -u "$UID" -x 'pcloud(\.bin)?' >/dev/null && return
    elif [[ $1 == wl-paste ]]; then
        pgrep -u "$UID" -f -- "(^|/)$*([[:space:]]|$)" >/dev/null && return
    else
        pgrep -u "$UID" -x -- "${1##*/}" >/dev/null && return
    fi
    systemd-cat --identifier="dots-autostart-${1##*/}" "$@" 9>&- &
}

spawnsl() {
    spawn "$@"
    sleep 1
}

dbus-update-activation-environment --systemd \
    WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
systemctl --user import-environment \
    WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
systemctl --user start \
    dots-battery.timer \
    hypridle.service \
    hyprpolkitagent.service \
    hyprsunset.service || true

bash "$HOME/.config/hypr/waybar.sh" ensure 9>&- &
spawn nm-applet --indicator
spawn blueman-applet
spawn pcloud
spawn mako
spawn wl-paste --type text --watch cliphist store
spawn wl-paste --type image --watch cliphist store

spawnsl discord
spawnsl spotify-launcher --skip-update
spawnsl alacritty
spawnsl nemo
spawnsl code
spawnsl firefox

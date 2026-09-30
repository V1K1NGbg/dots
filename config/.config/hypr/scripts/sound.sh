#!/usr/bin/env bash
set -eu
sounds=${XDG_DATA_HOME:-$HOME/.local/share}/dots-sounds
case ${1:-} in
    battery-low) file=$sounds/villager-deny1.ogg; volume=0.65;;
    battery-critical) file=$sounds/villager-hurt1.ogg; volume=0.85;;
    screenshot) file=$sounds/villager-accept1.ogg; volume=0.35;;
    timer) file=${2:-$sounds/villager-idle1.ogg}; volume=1.0;;
    *) exit 2;;
esac
# Respect the current output and mute state; never change the system volume.
exec pw-play --volume "$volume" "$file"

#!/usr/bin/env bash
set -eu
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
case ${1:-} in
    battery-low) file=$root/sounds/villager-deny1.ogg; volume=0.65;;
    battery-critical) file=$root/sounds/villager-hurt1.ogg; volume=0.85;;
    screenshot) file=$root/sounds/villager-accept1.ogg; volume=0.35;;
    timer) file=${2:-$root/sounds/villager-idle1.ogg}; volume=1.0;;
    *) exit 2;;
esac
# Respect the current output and mute state; never change the system volume.
exec pw-play --volume "$volume" "$file"

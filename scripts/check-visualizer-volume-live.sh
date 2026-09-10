#!/usr/bin/env bash
# With music playing, temporarily LOWER system/Spotify volume and restore both.
set -euo pipefail
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ | awk 'NR == 1 {gsub(",", "", $2); print $2}')
system_volume=$(wpctl get-volume "$sink" | awk '{print $2}')
spotify_volume=$(playerctl -p spotify volume)
binary=$(bash "$HOME/.config/hypr/visualizer.sh" --build)
scratch=$(mktemp -d "$XDG_RUNTIME_DIR/dots-volume-check.XXXXXXXX")
restore() {
    wpctl set-volume "$sink" "$system_volume"
    playerctl -p spotify volume "$spotify_volume"
    rm -rf -- "$scratch"
}
trap restore EXIT
trap 'exit 130' INT TERM HUP
sample() {
    local name=$1 status=0
    timeout 4 cava -p "$HOME/.config/hypr/visualizer-cava.conf" > "$scratch/raw" || status=$?
    [[ $status == 0 || $status == 124 ]]
    "$binary" --analyze < "$scratch/raw" > "$scratch/rendered"
    jq -se --arg name "$name" '
        [.[15:][].peak] |
        {test: $name, frames:length, mean_peak:(add / length)} |
        if .frames > 10 and .mean_peak >= 5 then . else error("Weak or silent playback sample") end
    ' "$scratch/rendered"
}
sample original
wpctl set-volume "$sink" "$(awk -v v="$system_volume" 'BEGIN {print v * 0.25}')"
sample system_quarter
wpctl set-volume "$sink" "$system_volume"
playerctl -p spotify volume "$(awk -v v="$spotify_volume" 'BEGIN {print v * 0.25}')"
sample spotify_quarter
wpctl set-volume "$sink" "$(awk -v v="$system_volume" 'BEGIN {print v * 0.25}')"
sample both_quarter
printf 'PASS: audible volume changes retain normalized peaks. Restoring system=%s Spotify=%s\n' "$system_volume" "$spotify_volume"

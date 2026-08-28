#!/usr/bin/env bash

# Media control functions
get_status() {
    local status player title artist
    status=$(playerctl --player=spotify,%any status 2>/dev/null)
    player=$(playerctl --player=spotify,%any metadata -f "{{playerName}}" 2>/dev/null)
    title=$(playerctl --player=spotify,%any metadata -f "{{title}}" 2>/dev/null)
    artist=$(playerctl --player=spotify,%any metadata -f "{{artist}}" 2>/dev/null)

    if [[ -n "$status" && "$status" != "No players found" ]]; then
        if [[ -n "$title" && -n "$artist" ]]; then
            echo "🎵 $artist - $title [$status]"
        elif [[ -n "$title" ]]; then
            echo "🎵 $title [$status]"
        else
            echo "🎵 $player [$status]"
        fi
    else
        echo "🎵 No media playing"
    fi
}

get_volume() {
    local volume
    volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "%.0f%%", $2 * 100}')
    if [[ -n "$volume" ]]; then
        echo "🔊 Volume: ${volume}"
    else
        echo "🔊 Volume: N/A"
    fi
}

# If no arguments, show the menu
if [[ $# -eq 0 ]]; then
    get_status
    get_volume
    echo "---"
    echo "⏯️  Play/Pause"
    echo "⏭️  Next Track"
    echo "⏮️  Previous Track"
    echo "🔇  Mute/Unmute"
    echo "🔉  Volume Down (-5%)"
    echo "🔊  Volume Up (+5%)"
    exit 0
fi

# Handle menu selection
case "$1" in
    "⏯️  Play/Pause")
        playerctl --player=spotify,%any play-pause
        ;;
    "⏭️  Next Track")
        playerctl --player=spotify,%any next
        ;;
    "⏮️  Previous Track")
        playerctl --player=spotify,%any previous
        ;;
    "🔇  Mute/Unmute")
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    "🔉  Volume Down (-5%)")
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        ;;
    "🔊  Volume Up (+5%)")
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
        ;;
    *)
        # If it's a status line, just exit
        exit 0
        ;;
esac

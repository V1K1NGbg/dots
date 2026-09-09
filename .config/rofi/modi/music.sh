#!/usr/bin/env bash
# Sourced by launcher.sh; uses the shared menu helpers.
outputs_menu() {
    local sinks default name streams id failed
    while :; do
        sinks=$(pactl -f json list sinks) || { info Outputs 'PipeWire is unavailable.'; return; }
        default=$(pactl get-default-sink)
        choose 'Audio outputs' 'Switch default and move all current playback.' list < <(jq -r --arg default "$default" '.[]|(if .name==$default then "● " else "○ " end)+(.description//.name)' <<<"$sinks") || return
        [[ $CHOICE == refresh ]] && continue
        name=$(jq -r ".[$CHOICE].name" <<<"$sinks")
        if ! pactl set-default-sink "$name"; then info Outputs 'This output is no longer available.'; continue; fi
        failed=''
        streams=$(pactl -f json list sink-inputs) || { info Outputs 'Default changed; could not enumerate playback streams.'; continue; }
        while IFS= read -r id; do pactl move-sink-input "$id" "$name" || failed+=" $id"; done < <(jq -r '.[].index' <<<"$streams")
        [[ -z $failed ]] || info Outputs "Default changed; these streams could not move:$failed"
        return
    done
}
music_menu() {
    local message selected=0
    while :; do
        message=$(playerctl --player=spotify,%any metadata -f '{{artist}} — {{title}}' 2>/dev/null || printf 'No media playing')
        message=${message:-Nothing playing}
        message+=$'\n'$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "Volume %d%%", $2*100; if ($3 ~ /MUTED/) printf " · muted"; print ""}' || :)
        choose Music "$message" list -selected-row "$selected" <<< $'Play / Pause\nNext track\nPrevious track\nMute / Unmute\nVolume −5%\nVolume +5%\nAudio outputs' || return
        [[ $CHOICE == refresh ]] && continue; selected=$CHOICE
        case $CHOICE in
            6) outputs_menu;; 0) playerctl --player=spotify,%any play-pause;;
            1) playerctl --player=spotify,%any next;; 2) playerctl --player=spotify,%any previous;;
            3) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle;; 4) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-;;
            5) wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+;;
        esac
        return
    done
}

#!/usr/bin/env bash
# Sourced by launcher.sh; uses the shared menu helpers.
outputs_menu() {
    local sinks default rows name streams ids id failed
    while :; do
        if ! sinks=$(pactl -f json list sinks) || ! default=$(pactl get-default-sink); then
            info Outputs 'PipeWire is unavailable.' || :; return 10
        fi
        # Keep exactly one display row per sink, even with control characters in its label.
        if ! rows=$(jq -r --arg default "$default" '.[]|(if .name==$default then "● " else "○ " end)+((.description//.name)|gsub("[[:cntrl:]]"; " "))' <<<"$sinks"); then
            info Outputs 'Could not read audio outputs.' || :; return 10
        fi
        [[ -n $rows ]] || { info Outputs 'No audio outputs available.' || :; return 10; }
        choose 'Audio outputs' 'Switch default and move all current playback.' list <<<"$rows" || return
        [[ $CHOICE == refresh ]] && continue
        if ! name=$(jq -er --argjson index "$CHOICE" '.[$index].name | select(type=="string" and length>0)' <<<"$sinks"); then
            info Outputs 'This output is no longer available.' || :; return 10
        fi
        if ! pactl set-default-sink "$name"; then info Outputs 'This output is no longer available.'; continue; fi
        failed=''
        if ! streams=$(pactl -f json list sink-inputs) || ! ids=$(jq -r '.[].index' <<<"$streams"); then
            info Outputs 'Default changed; could not enumerate playback streams.' || :; return 10
        fi
        while IFS= read -r id; do
            [[ -n $id ]] || continue
            pactl move-sink-input "$id" "$name" || failed+=" $id"
        done <<<"$ids"
        [[ -z $failed ]] || { info Outputs "Default changed; these streams could not move:$failed" || :; return 10; }
        return
    done
}
music_menu() {
    local message selected=0 command=()
    while :; do
        message=$(playerctl --player=spotify,%any metadata -f '{{artist}} — {{title}}' 2>/dev/null || printf 'No media playing')
        message=${message:-Nothing playing}
        message+=$'\n'$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "Volume %d%%", $2*100; if ($3 ~ /MUTED/) printf " · muted"; print ""}' || :)
        choose Music "$message" list -selected-row "$selected" <<< $'Play / Pause\nNext track\nPrevious track\nMute / Unmute\nVolume −5%\nVolume +5%\nAudio outputs' || return
        [[ $CHOICE == refresh ]] && continue
        if [[ $CHOICE == 6 ]]; then outputs_menu; return $?; fi
        case $CHOICE in
            0) command=(playerctl --player=spotify,%any play-pause);;
            1) command=(playerctl --player=spotify,%any next);; 2) command=(playerctl --player=spotify,%any previous);;
            3) command=(wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle);; 4) command=(wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-);;
            5) command=(wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+);;
        esac
        if ! message=$("${command[@]}" 2>&1); then
            info Music "${message:-Media action failed.}" || :; return 10
        fi
        if [[ $CHOICE == 4 || $CHOICE == 5 ]]; then selected=$CHOICE; continue; fi
        return
    done
}

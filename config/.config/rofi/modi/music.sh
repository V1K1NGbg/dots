#!/usr/bin/env bash
# Sourced by launcher.sh. Playback, volume and audio outputs on one page.
music_switch_output() {
    local name=$1 streams id failed=''
    pactl set-default-sink "$name" || { info 'Music & Audio' 'This output is no longer available.' || :; return 10; }
    if ! streams=$(pactl -f json list sink-inputs | jq -r '.[].index'); then
        info 'Music & Audio' 'Default changed; could not enumerate playback streams.' || :; return 10
    fi
    while IFS= read -r id; do
        [[ -n $id ]] || continue
        pactl move-sink-input "$id" "$name" || failed+=" $id"
    done <<<"$streams"
    [[ -z $failed ]] || { info 'Music & Audio' "Default changed; these streams could not move:$failed" || :; return 10; }
}
music_menu() {
    local message selected=0 sinks='' default='' outputs=() names=() name label rows command=()
    while :; do
        message=$(playerctl --player=spotify,%any metadata -f '{{artist}} — {{title}}' 2>/dev/null || printf 'No media playing')
        message=${message:-Nothing playing}
        message+=$'\n'$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "Volume %d%%", $2*100; if ($3 ~ /MUTED/) printf " · muted"; print ""}' || :)
        outputs=() names=()
        if sinks=$(pactl -f json list sinks 2>/dev/null) && default=$(pactl get-default-sink 2>/dev/null); then
            while IFS=$'\t' read -r name label; do
                names+=("$name")
                if [[ $name == "$default" ]]; then outputs+=("● $label"); else outputs+=("○ $label"); fi
            done < <(jq -r '.[]|[.name, ((.description//.name)|gsub("[[:cntrl:]]"; " "))]|@tsv' <<<"$sinks")
        fi
        rows=$'Play / Pause\nNext track\nPrevious track\nVolume +5%\nVolume −5%\nMute / Unmute'
        ((${#outputs[@]})) && rows+=$'\n## Output\n'$(printf '%s\n' "${outputs[@]}")
        choose 'Music & Audio' "$message" list -selected-row "$selected" <<<"$rows" || return
        [[ $CHOICE == refresh ]] && continue
        case $CHOICE in
            0) command=(playerctl --player=spotify,%any play-pause);;
            1) command=(playerctl --player=spotify,%any next);;
            2) command=(playerctl --player=spotify,%any previous);;
            3) command=(wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+);;
            4) command=(wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-);;
            5) command=(wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle);;
            6) continue;;
            *)
                name=${names[CHOICE-7]:-}
                [[ -n $name ]] || continue
                music_switch_output "$name"; return;;
        esac
        if ! message=$("${command[@]}" 2>&1); then
            info 'Music & Audio' "${message:-Media action failed.}" || :; return 10
        fi
        # Volume and mute stay open for repeated presses.
        if ((CHOICE>=3)); then selected=$CHOICE; continue; fi
        return
    done
}

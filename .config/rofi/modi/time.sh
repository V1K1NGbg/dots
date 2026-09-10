#!/usr/bin/env bash
# Sourced by launcher.sh; uses the shared menu helpers.
watch_menu() {
    local state running value laps rows
    while :; do
        state=$("$ROOT/modi/time.sh" status)
        value=$(jq --argjson now "$(date +%s)" '(.watch.elapsed//0)+(if .watch.started then $now-.watch.started else 0 end)' <<<"$state")
        running=$(jq -r '.watch.started//false' <<<"$state")
        rows=$'Start / Resume\nLap\nReset'; [[ $running == false ]] || rows=$'Pause\nLap\nReset'
        laps=$(jq -r '(.watch.laps//[])|to_entries|.[-8:][]|"Lap \(.key+1): \(.value|floor)s"' <<<"$state")
        choose Stopwatch "$(hms "$value")${laps:+$'\n'$laps}" list <<<"$rows" || return
        case $CHOICE in
            0) if [[ $running == false ]]; then "$ROOT/modi/time.sh" watch-start; else "$ROOT/modi/time.sh" watch-pause; fi;;
            1) "$ROOT/modi/time.sh" watch-lap;; 2) "$ROOT/modi/time.sh" watch-reset;;
        esac
        return
    done
}
time_menu() {
    local state rows item id action repeat input error label
    while :; do
        state=$("$ROOT/modi/time.sh" status)
        rows=$(jq --argjson now "$(date +%s)" '[{label:"New timer",action:"timer"},{label:"New alarm",action:"alarm"},{label:"Stopwatch",action:"watch"}]+
          [.items[]|{id:.id,action:"delete",label:(.label+" · "+(if .due==null then "completed" elif .kind=="timer" then (([.due-$now,0]|max|floor|tostring)+"s remaining") else (.clock+" · "+(.repeat//"once")) end))}]' <<<"$state")
        choose Time 'Timers and alarms are scheduled by systemd.' list < <(jq -r '.[].label|gsub("[\u0000-\u001f\u007f]";" ")' <<<"$rows") || return
        [[ $CHOICE == refresh ]] && continue
        item=$(jq ".[$CHOICE]" <<<"$rows"); action=$(jq -r .action <<<"$item"); id=$(jq -r '.id//""' <<<"$item")
        case $action in
            timer|alarm) live_menu time "$action"; return;;
            watch) watch_menu;;
            delete) choose 'Delete clock?' '' list <<< $'Delete\nBack' && [[ $CHOICE == 0 ]] && "$ROOT/modi/time.sh" delete "$id";;
        esac
        return
    done
}

# Live validation is performed on input changes; only acceptance saves a clock.
time_live() {
    local kind=$1 event name input='' duration label seconds due message rows repeat error
    while :; do
        duration=${input%% *}; label=${input#* }
        if [[ $input != *' '* || -z $label ]]; then
            if [[ $kind == timer ]]; then label=Timer; else label=Alarm; fi
        fi
        rows='[]'
        if [[ $kind == timer ]]; then
            message='Duration and optional name: 10m Tea · 1h30m Laundry'
            if [[ -n $input ]]; then
                if seconds=$("$ROOT/modi/time.sh" duration "$duration"); then
                    message="$(hms "$seconds") · $label"
                    rows='[{"text":"Start timer","data":"once"}]'
                else message='Invalid duration. Use 10m, 1h30m, or 30s (at least 1 second).'; fi
            fi
        else
            message='24-hour time and optional name: 07:30 Wake up'
            if [[ -n $input ]]; then
                if due=$("$ROOT/modi/time.sh" next "$duration" once); then
                    message="Next: $(at_epoch "$due" '+%a %d %b, %H:%M') · $label"
                    rows='[{"text":"Set alarm · once","data":"once"},{"text":"Set alarm · daily","data":"daily"},{"text":"Set alarm · weekdays","data":"weekdays"}]'
                else message='Invalid time. Use HH:MM, from 00:00 to 23:59.'; fi
            fi
        fi
        live_page "New $kind" "$message" "$rows"
        IFS= read -r event || return 0
        name=$(jq -r .name <<<"$event")
        case $name in
            'input change') input=$(jq -r .value <<<"$event");;
            'select entry'|'execute custom input')
                [[ $rows != '[]' ]] || continue
                repeat=$(jq -r '.data//""' <<<"$event"); repeat=${repeat:-once}
                if [[ $kind == timer ]]; then error=$("$ROOT/modi/time.sh" add-timer "$duration" "$label" 2>&1)
                else error=$("$ROOT/modi/time.sh" add-alarm "$duration" "$repeat" "$label" 2>&1); fi
                if [[ $? == 0 ]]; then return; fi
                live_page "New $kind" "$error" '["Close"]'
                IFS= read -r event || :; return;;
        esac
    done
}

clock_read() { if [[ -f $STATE/clocks.json ]]; then cat "$STATE/clocks.json"; else printf '{"items":[],"alerts":[],"watch":{}}'; fi; }
duration_seconds() {
    awk -v text="$1" 'BEGIN {
      gsub(/[[:space:]]/,"",text); total=0
      while(match(text,/^[0-9]+([.][0-9]+)?[smhd]/)) {
        part=substr(text,1,RLENGTH); unit=substr(part,length(part)); value=part+0
        total+=value*(unit=="s"?1:unit=="m"?60:unit=="h"?3600:86400)
        text=substr(text,RLENGTH+1)
      }
      if(length(text)||total<1||total>31622400)exit 1
      printf "%.0f\n",total
    }'
}
next_alarm() {
    local clock=$1 repeat=$2 now=$3 noon day candidate offset dow
    [[ $clock =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]] || return 1
    [[ $repeat == once || $repeat == daily || $repeat == weekdays ]] || return 1
    day=$(at_epoch "$now" +%F); noon=$(wall_epoch "$day 12:00")
    for offset in 0 1 2 3 4 5 6 7; do
        day=$(at_epoch "$((noon+offset*86400))" +%F)
        candidate=$(wall_epoch "$day $clock") || continue
        dow=$(at_epoch "$candidate" +%u)
        if ((candidate>now)) && { [[ $repeat != weekdays ]] || ((dow<6)); }; then printf '%s\n' "$candidate"; return; fi
    done
    return 1
}

# One native calendar timer waits for the earliest saved deadline. This function
# runs only after a clock changes or expires; no process polls the clock file.
schedule() {
    local due directory
    due=$(jq -r '[.items[].due|select(.!=null)]|min // empty' <<<"$json")
    if [[ -z $due ]]; then
        systemctl --user disable --now dots-utils-clock.timer >/dev/null 2>&1 || :
        return
    fi
    directory=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/dots-utils-clock.timer.d
    mkdir -p "$directory" || return
    { printf '[Timer]\nOnCalendar=\nOnCalendar=%s\n' "$(at_epoch "$due" '+%Y-%m-%d %H:%M:%S')"; } | atomic "$directory/deadline.conf" || return
    systemctl --user daemon-reload || return
    systemctl --user enable dots-utils-clock.timer >/dev/null || return
    systemctl --user restart --no-block dots-utils-clock.timer
}

alert() (
    id=$1
    label=$(clock_read | jq -r --arg id "$id" '.alerts[]|select(.id==$id)|.label')
    [[ -n $label ]] || return 0
    timeout 30 "$0" sound & sound_pid=$!
    trap 'kill "$sound_pid" 2>/dev/null || :; if [[ -f $RUNTIME/notification-$id ]]; then busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications CloseNotification u "$(cat "$RUNTIME/notification-$id")" >/dev/null 2>&1 || :; rm -f -- "$RUNTIME/notification-$id"; fi' EXIT
    trap 'exit 0' TERM INT
    while IFS= read -r action; do
        case $action in
            default) "$0" dismiss "$id"; break;;
            *) [[ $action =~ ^[0-9]+$ ]] && printf '%s' "$action" > "$RUNTIME/notification-$id";;
        esac
    done < <(notify-send --app-name='Desktop Clocks' --urgency=critical --expire-time=0 --print-id --wait \
        --action=default=Stop -- "$label" 'Timer or alarm due.')
    kill "$sound_pid" 2>/dev/null || :
    # Closing the notification without invoking its default action also stops it.
    "$0" dismiss "$id"
)
clock_command() (
set -euo pipefail
case ${1:-status} in
    duration) duration_seconds "$2"; exit;;
    next) next_alarm "$2" "$3" "${4:-$(date +%s)}"; exit;;
    status) clock_read; exit;;
    sound)
        sound=$(cfg '.sound // empty')
        trap 'for pid in $(jobs -pr); do kill "$pid" 2>/dev/null || :; done' EXIT
        trap 'exit 0' TERM INT
        while :; do bash "$ROOT/../hypr/sound.sh" timer "$sound" & wait $! || exit; sleep .5 & wait $! || :; done;;
    alert) alert "$2"; exit;;
esac
exec 9>"$STATE/clocks.lock"; flock 9
json=$(clock_read)
now=$(date +%s); id=${2:-}; spawned=()
case $1 in
    add-timer)
        seconds=$(duration_seconds "$2") || { printf 'Use a duration such as 10m or 1h30m\n' >&2; exit 1; }
        id=$(id_new)
        json=$(jq --arg id "$id" --arg label "${3:-Timer}" --argjson due "$((now+seconds))" '.items += [{id:$id,label:$label,kind:"timer",due:$due}]' <<<"$json");;
    add-alarm)
        due=$(next_alarm "$2" "$3" "$now") || { printf 'Use HH:MM and once, daily, or weekdays\n' >&2; exit 1; }
        json=$(jq --arg id "$(id_new)" --arg label "${4:-Alarm}" --arg clock "$2" --arg repeat "$3" --argjson due "$due" '.items += [{id:$id,label:$label,kind:"alarm",clock:$clock,repeat:$repeat,due:$due}]' <<<"$json");;
    delete) json=$(jq --arg id "$id" '.items |= map(select(.id!=$id))' <<<"$json");;
    dismiss)
        [[ $id =~ ^[a-zA-Z0-9-]+$ ]] || exit 1
        json=$(jq --arg id "$id" '.alerts |= map(select(.id!=$id))' <<<"$json");;
    watch-*)
        action=${1#watch-}
        json=$(jq --arg action "$action" --argjson now "$now" '
          ((.watch.elapsed//0)+(if .watch.started then $now-.watch.started else 0 end)|[.,0]|max) as $elapsed |
          if $action=="start" then .watch.started=(.watch.started//$now)
          elif $action=="pause" then .watch.elapsed=$elapsed|.watch.started=null
          elif $action=="reset" then .watch={}
          elif $action=="lap" then .watch.laps=((.watch.laps//[])+[$elapsed]) else error("Unknown stopwatch action") end' <<<"$json");;
    reconcile|fire)
        while IFS= read -r item; do
            id=$(jq -r .id <<<"$item"); repeat=$(jq -r '.repeat//"once"' <<<"$item"); next=null
            if [[ $repeat != once ]]; then next=$(next_alarm "$(jq -r .clock <<<"$item")" "$repeat" "$now"); fi
            alert_id=$(id_new); spawned+=("$alert_id")
            json=$(jq --arg id "$id" --arg aid "$alert_id" --argjson next "$next" --argjson now "$now" '
              (.items[]|select(.id==$id)|.label) as $label |
              .items |= map(if .id==$id then .due=$next else . end) |
              .alerts += [{id:$aid,label:$label,fired:$now}]' <<<"$json")
        done < <(jq -c --argjson now "$now" '.items[]|select(.due!=null and .due<=$now)' <<<"$json")
        ;;
    *) printf 'Unknown clock action\n' >&2; exit 2;;
esac
printf '%s\n' "$json" | atomic "$STATE/clocks.json"
case $1 in
    watch-*|dismiss) ;; # Stopwatch state needs no scheduled work.
    *) schedule || { printf 'Clock saved, but systemd scheduling failed. Run time.sh reconcile to retry.\n' >&2; exit 1; };;
esac
flock -u 9
case $1 in
    dismiss) systemctl --user stop "dots-utils-alert-$id.service" 9>&- || :;;
    reconcile|fire) for id in "${spawned[@]-}"; do [[ -n $id ]] || continue; systemd-run --user --collect --quiet --unit="dots-utils-alert-$id" "$0" alert "$id" 9>&-; done;;
esac

)

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    source "$(dirname -- "$0")/common.sh"
    if [[ ${1:-} == live ]]; then time_live "${2:-timer}"
    else clock_command "${@:-status}"; fi
fi

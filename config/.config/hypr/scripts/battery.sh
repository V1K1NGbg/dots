#!/usr/bin/env bash
set -eu
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state=${XDG_RUNTIME_DIR:?}/dots-battery
mkdir -p "$state"
# Invoked by a single systemd oneshot; no resident polling process.
# The override allows fixture checks without touching real battery state.
for battery in "${DOTS_POWER_SUPPLY_ROOT:-/sys/class/power_supply}"/*; do
    [[ -r $battery/type && $(cat "$battery/type") == Battery ]] || continue
    [[ ! -r $battery/scope || $(cat "$battery/scope") != Device ]] || continue
    [[ ! -r $battery/present || $(cat "$battery/present") == 1 ]] || continue
    [[ -r $battery/capacity && -r $battery/status ]] || continue
    capacity=$(cat "$battery/capacity")
    [[ $capacity =~ ^[0-9]+$ ]] || continue
    capacity=$((10#$capacity))
    ((capacity <= 100)) || continue
    name=${battery##*/}
    previous=0
    if [[ -r $state/$name ]]; then read -r previous < "$state/$name" || previous=0; fi
    case $previous in 0|1|2) ;; *) previous=0;; esac
    # Two percentage points of hysteresis prevent repeated alerts from jitter.
    if ((capacity > 22)); then previous=0
    elif ((capacity > 12 && previous == 2)); then previous=1
    fi
    level=0
    if [[ $(cat "$battery/status") == Discharging ]]; then
        if ((capacity <= 10)); then level=2
        elif ((capacity <= 20)); then level=1
        fi
    fi
    if ((level > previous)); then
        previous=$level
        if ((level == 2)); then
            event=battery-critical; title='Battery critical'; urgency=critical
        else
            event=battery-low; title='Battery low'; urgency=normal
        fi
        notify-send --app-name='Desktop Battery' --urgency="$urgency" \
            "$title" "$name: $capacity% remaining. Connect your charger." || :
        bash "$root/sound.sh" "$event" || :
    fi
    printf '%s\n' "$previous" > "$state/$name"
done

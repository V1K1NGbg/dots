#!/usr/bin/env bash
# Session power policy. Runtime commands never depend on the dots checkout.
POWER_SUPPLIES=/sys/class/power_supply
POWER_LIDS=/proc/acpi/button/lid
POWER_STATE=${XDG_RUNTIME_DIR:?}/dots-power

power_source() {
    local supply type online scope seen=false
    for supply in "$POWER_SUPPLIES"/*; do
        read -r type < "$supply/type" 2>/dev/null || continue
        [[ $type != Battery && $type != UPS ]] || continue
        scope=''; [[ ! -r $supply/scope ]] || read -r scope < "$supply/scope"
        [[ $scope != Device ]] || continue
        read -r online < "$supply/online" 2>/dev/null || continue
        case $online in
            1) printf 'ac\n'; return;;
            0) seen=true;;
        esac
    done
    if $seen; then printf 'battery\n'; else printf 'unknown\n'; fi
}

power_dpms() {
    local result
    result=$(hyprctl dispatch "hl.dsp.dpms({ action = \"$1\" })") || return
    [[ $result == ok ]]
}

power_lock() {
    local attempt
    if hyprctl -j locked | jq -e '.locked == true' >/dev/null; then return; fi
    hyprctl dispatch 'hl.dsp.exec_cmd("pidof hyprlock || hyprlock --grace 0")' >/dev/null || return
    for ((attempt=0; attempt<100; attempt++)); do
        if hyprctl -j locked | jq -e '.locked == true' >/dev/null; then return; fi
        sleep .1
    done
    printf 'Session did not lock; refusing screen-off/suspend.\n' >&2
    return 1
}

power_idle() {
    [[ ! -f $POWER_STATE/caffeine && $(power_source) == "$1" ]] || return 0
    power_lock || return
    # Power may have changed while the locker acquired the session.
    [[ ! -f $POWER_STATE/caffeine && $(power_source) == "$1" ]] || return 0
    power_suspend
}

power_caffeine() (
    umask 077; mkdir -p "$POWER_STATE"
    exec 8>"$POWER_STATE/lock"; flock -x 8
    if [[ -f $POWER_STATE/caffeine ]]; then
        # Reset inactivity before allowing automatic actions again.
        systemctl --user restart hypridle.service || return
        rm -f -- "$POWER_STATE/caffeine"
    else
        touch "$POWER_STATE/caffeine"
        power_dpms enable || return
        rm -f -- "$POWER_STATE/lid-blanked" "$POWER_STATE/lid-suspended"
    fi
)

power_suspend() {
    local capability
    capability=$(busctl call org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager CanSuspend) || return
    case $capability in
        's "yes"'|'s "challenge"') ;;
        *) printf 'Suspend is unavailable; check the system sleep policy.\n' >&2; return 1;;
    esac
    power_lock || return
    systemctl suspend
}

power_lid_state() {
    local path line state=unknown
    for path in "$POWER_LIDS"/*/state; do
        [[ -r $path ]] || continue
        read -r line < "$path"
        case $line in
            *closed) printf 'closed\n'; return;;
            *open) state=open;;
        esac
    done
    printf '%s\n' "$state"
}

power_external() {
    hyprctl monitors all -j | jq -r '
      if type != "array" or length == 0 then error("No monitor information")
      else any(.[]; (.name|test("^(eDP-|LVDS-|DSI-)")|not) and (.disabled//false|not)) end'
}

power_lid() (
    local lid external
    umask 077; mkdir -p "$POWER_STATE"
    exec 8>"$POWER_STATE/lock"; flock -x 8
    [[ ! -f $POWER_STATE/caffeine ]] || return 0
    lid=$(power_lid_state)
    external=$(power_external) || return
    if [[ $lid == open || $external == true ]]; then
        rm -f -- "$POWER_STATE/lid-suspended"
        if [[ -f $POWER_STATE/lid-blanked ]]; then power_dpms enable || return; rm -f "$POWER_STATE/lid-blanked"; fi
        return
    fi
    if [[ $lid != closed ]]; then rm -f -- "$POWER_STATE/lid-suspended"; return; fi
    power_lock || return
    # Opening the lid or docking while the locker starts cancels this action.
    [[ $(power_lid_state) == closed && $(power_external) == false ]] || return 0
    power_dpms disable || return
    touch "$POWER_STATE/lid-blanked"
    if [[ $(power_source) == battery ]]; then
        if [[ ! -f $POWER_STATE/lid-suspended ]]; then
            # One attempt per closure/eligibility transition; no resume retry loop.
            touch "$POWER_STATE/lid-suspended"
            power_suspend
        fi
    else
        rm -f -- "$POWER_STATE/lid-suspended"
    fi
)

power_resume() {
    if [[ $(power_lid_state) == closed && $(power_external) == false ]]; then return 0; fi
    power_dpms enable
}

power_changed() (
    local current previous=''
    umask 077
    mkdir -p "$POWER_STATE"
    exec 8>"$POWER_STATE/lock"; flock -x 8
    current=$(power_source)
    [[ ! -f $POWER_STATE/source ]] || read -r previous < "$POWER_STATE/source"
    [[ $current != "$previous" ]] || return 0
    [[ $current != unknown ]] || printf 'Power source unavailable; automatic idle/suspend suppressed.\n' >&2
    # A new power source starts a full inactivity interval. Never unlock here.
    systemctl --user restart hypridle.service || return
    printf '%s\n' "$current" > "$POWER_STATE/source"
)

power_watch() {
    power_changed || return
    power_lid || return
    udevadm monitor --udev --subsystem-match=power_supply | while IFS= read -r event; do
        [[ $event != UDEV* ]] || { power_changed; power_lid; }
    done
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    case ${1:-} in
        idle) power_idle "${2:-battery}";;
        caffeine) power_caffeine;;
        resume) power_resume;;
        lock) power_lock;;
        suspend) power_suspend;;
        lid) power_lid;;
        lid-state) power_lid_state;;
        power-changed) power_changed;;
        watch) power_watch;;
        *) printf 'Usage: power.sh idle [battery|ac]|caffeine|resume|lock|suspend|lid|lid-state|power-changed|watch\n' >&2; exit 2;;
    esac
fi

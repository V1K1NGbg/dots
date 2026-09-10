#!/usr/bin/env bash
# Own only the desktop bar; the edge visualizer is a separate Waybar process.
set -euo pipefail
runtime=${XDG_RUNTIME_DIR:?}/dots-waybar-control
mkdir -p "$runtime"
exec 9>"$runtime/lock"
flock 9
action=${1:-ensure}
case $action in
    show|hide) printf '%s\n' "$action" > "$runtime/desired";;
    ensure|restart|stop|refresh) ;;
    *) exit 2;;
esac
pid=0
[[ ! -r $runtime/pid ]] || read -r pid < "$runtime/pid"
owned=false
if [[ $pid =~ ^[1-9][0-9]*$ && -r /proc/$pid/cmdline ]] && kill -0 "$pid" 2>/dev/null; then
    # Validate the command as well as the PID, which can be reused after exit.
    mapfile -d '' -t args < "/proc/$pid/cmdline"
    if [[ ${args[0]:-} == waybar && ${args[1]:-} == --config &&
          ${args[2]:-} == "$HOME/.config/waybar/config.jsonc" ]]; then owned=true; fi
fi
if [[ $action == stop || $action == restart ]] && $owned; then
    kill -TERM "$pid"
    for ((attempt=0; attempt<100; attempt++)); do
        kill -0 "$pid" 2>/dev/null || break
        sleep .05
    done
    if kill -0 "$pid" 2>/dev/null; then
        printf 'Waybar did not stop; refusing to launch a duplicate.\n' >&2; exit 1
    fi
    owned=false
fi
[[ $action != stop ]] || exit 0
if [[ $action == refresh ]]; then
    if $owned && [[ -r $runtime/applied ]]; then
        read -r ready_pid _ < "$runtime/applied"
        [[ $ready_pid != "$pid" ]] || kill -RTMIN+9 "$pid"
    fi
    exit
fi
if ! $owned; then
    nohup waybar --config "$HOME/.config/waybar/config.jsonc" \
        --style "$HOME/.config/waybar/style.css" \
        > "$runtime/waybar.log" 2>&1 < /dev/null 9>&- &
    pid=$!
    printf '%s\n' "$pid" > "$runtime/pid"
fi
# A signal before Waybar installs its handlers terminates the process. Wait for
# the SIGUSR1 handler instead of assuming that a fixed startup delay is enough.
ready=false
for ((attempt=0; attempt<100; attempt++)); do
    if [[ $pid =~ ^[1-9][0-9]*$ && -r /proc/$pid/status ]]; then
        caught=$(awk '$1 == "SigCgt:" {print $2}' "/proc/$pid/status")
        if [[ -n $caught ]] && (( (16#$caught & 512) != 0 )) &&
            hyprctl layers -j | jq -e --argjson pid "$pid" \
                'any(.. | objects; .pid? == $pid and .namespace? == "waybar")' >/dev/null; then
            ready=true; break
        fi
    fi
    sleep .05
done
$ready || { printf 'Waybar did not become ready; see %s/waybar.log\n' "$runtime" >&2; exit 1; }
desired=hide
[[ ! -r $runtime/desired ]] || read -r desired < "$runtime/desired"
old_pid=0; applied=hide
[[ ! -r $runtime/applied ]] || read -r old_pid applied < "$runtime/applied"
[[ $old_pid == "$pid" ]] || applied=hide
if [[ $desired != "$applied" ]]; then
    kill -USR1 "$pid"
fi
printf '%s %s\n' "$pid" "$desired" > "$runtime/applied"

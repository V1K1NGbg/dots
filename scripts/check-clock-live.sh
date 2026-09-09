#!/usr/bin/env bash
# Test installed native clock delivery. Only uniquely named test clocks are removed.
set -euo pipefail
clock=$HOME/.config/rofi/modi/time.sh
source "$HOME/.config/rofi/modi/common.sh"
label="Dots clock test $$"; clock_id=''; alert_id=''
cleanup() {
    if [[ -n $alert_id ]]; then "$clock" dismiss "$alert_id" >/dev/null 2>&1 || :; fi
    if [[ -n $clock_id ]]; then "$clock" delete "$clock_id" >/dev/null 2>&1 || :; fi
}
trap cleanup EXIT
! systemctl --user is-active --quiet dots-utils.service
pending=$("$clock" status | jq '[.items[]|select(.due!=null)]|length')
"$clock" add-timer 3s "$label"
clock_id=$("$clock" status | jq -er --arg label "$label" '.items[]|select(.label==$label)|.id')
systemctl --user is-active --quiet dots-utils-clock.timer
# When no personal clocks are waiting, also simulate an inactive timer crossing
# its deadline. Persistent=true must deliver the missed deadline on restart.
if ((pending==0)); then
    systemctl --user stop dots-utils-clock.timer
    sleep 4
    systemctl --user start dots-utils-clock.timer
fi
for attempt in {1..150}; do
    alert_id=$("$clock" status | jq -r --arg label "$label" '.alerts[]|select(.label==$label)|.id')
    [[ -z $alert_id ]] || break
    sleep .1
done
[[ -n $alert_id ]] || { journalctl --user -u dots-utils-clock.service -n 20 --no-pager; exit 1; }
for attempt in {1..50}; do
    systemctl --user is-active --quiet "dots-utils-alert-$alert_id.service" && break
    sleep .1
done
systemctl --user is-active --quiet "dots-utils-alert-$alert_id.service"
"$clock" status | jq -e --arg label "$label" '[.alerts[]|select(.label==$label)]|length==1' >/dev/null
# Invoke exactly the action used by Mako's default left-click binding.
for attempt in {1..50}; do
    [[ -s $RUNTIME/notification-$alert_id ]] && break
    sleep .1
done
notification_id=$(cat "$RUNTIME/notification-$alert_id")
if [[ ${1:-} == --close ]]; then
    makoctl dismiss -n "$notification_id"
else
    makoctl invoke -n "$notification_id" default
fi
for attempt in {1..50}; do
    if ! systemctl --user is-active --quiet "dots-utils-alert-$alert_id.service"; then break; fi
    sleep .1
done
"$clock" status | jq -e --arg id "$alert_id" 'all(.alerts[]; .id!=$id)' >/dev/null
! systemctl --user is-active --quiet "dots-utils-alert-$alert_id.service"
"$clock" delete "$clock_id"
clock_id=''; alert_id=''
if ((pending==0)); then ! systemctl --user is-active --quiet dots-utils-clock.timer; fi
printf 'PASS: native timer delivery, notification/sound unit, dismissal, cleanup (prior pending clocks: %s)\n' "$pending"

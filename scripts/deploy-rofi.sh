#!/usr/bin/env bash
# Run in the laptop session: deploy-rofi.sh SNAPSHOT, or --restore BACKUP.
set -euo pipefail
restore=false; if [[ ${1:-} == --restore ]]; then restore=true; shift; fi
source_dir=$(cd -- "${1:?Pass a snapshot or backup directory}" && pwd)
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
instance=$(hyprctl instances -j | jq -e 'if length==1 then .[0] else error("Expected one Hyprland session") end')
export HYPRLAND_INSTANCE_SIGNATURE=$(jq -r .instance <<<"$instance")
export WAYLAND_DISPLAY=$(jq -r .wl_socket <<<"$instance")
units=(dots-rofi.service dots-desktop.service desktop-utils.service utils.service dots-utils.service dots-utils-clock.timer)
reload() {
    systemctl --user daemon-reload
    hyprctl reload
    errors=$(hyprctl configerrors); [[ -z $errors ]] || { printf '%s\n' "$errors" >&2; return 1; }
}
stop_workers() {
    for unit in "${units[@]}"; do systemctl --user disable --now "$unit" >/dev/null 2>&1 || :; done
    systemctl --user stop 'dots-rofi-alert-*.service' 'dots-desktop-alert-*.service' 'desktop-utils-alert-*.service' 'utils-alert-*.service' 'dots-utils-alert-*.service' dots-rofi-ai.service >/dev/null 2>&1 || :
}
restore_backup() {
    local backup=$1 record name unit
    stop_workers
    while IFS= read -r record; do
        name=$(jq -r .name <<<"$record")
        if [[ $(jq -r .existed <<<"$record") == true ]]; then mkdir -p "$HOME/${name%/*}"; cp -p "$backup/$name" "$HOME/$name"; else rm -f -- "$HOME/$name"; fi
    done < <(jq -c '.files | if type=="object" then to_entries|map({name:.key,existed:.value}) else . end | .[]' "$backup/manifest.json")
    reload
    while IFS= read -r record; do
        unit=$(jq -r .name <<<"$record")
        if jq -e .enabled <<<"$record" >/dev/null; then systemctl --user enable "$unit"; fi
        if jq -e .active <<<"$record" >/dev/null; then systemctl --user start "$unit"; fi
    done < <(jq -c '(.units // [{name:"dots-rofi.service",enabled:.enabled,active:.active}])[]' "$backup/manifest.json")
}
if $restore; then restore_backup "$source_dir"; printf 'Restored configuration; personal clock data retained.\n'; exit; fi
for cmd in bash jq curl fd fzf alacritty flock timeout busctl rofi pactl wpctl pw-play notify-send code playerctl; do command -v "$cmd" >/dev/null || { printf 'Missing dependency: %s\n' "$cmd" >&2; exit 1; }; done
ROFI_PLUGIN_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/rofi/plugins${ROFI_PLUGIN_PATH:+:$ROFI_PLUGIN_PATH}" rofi -no-config -help 2>/dev/null | grep blocks >/dev/null || { printf 'Missing rofi-blocks-git: install with paru -S --needed rofi-blocks-git\n' >&2; exit 1; }
bash "$source_dir/scripts/check-rofi.sh"
rofi -no-config -theme "$source_dir/.config/rofi/theme.rasi" -dump-theme >/dev/null
files=(.config/systemd/user/dots-utils-clock.service .config/systemd/user/dots-utils-clock.timer .config/hypr/sound.sh .config/hypr/sounds/villager-idle1.ogg .config/hypr/sounds/README.md)
while IFS= read -r -d '' path; do files+=("${path#"$source_dir/"}"); done < <(find "$source_dir/.config/rofi" -type f -print0)
old=(.config/systemd/user/dots-rofi.service .config/rofi/windows.py .config/systemd/user/dots-utils.service .config/rofi/utils/worker.sh .config/rofi/modi/tray.sh .config/rofi/icon-gen/sources/inbox.svg .config/rofi/icon-gen/icons/inbox.svg)
old+=(.config/systemd/user/dots-desktop.service)
old+=(.config/systemd/user/desktop-utils.service)
old+=(.config/systemd/user/utils.service)
old+=(.config/rofi/lib/ai.sh .config/rofi/lib/common.sh)
old+=(.config/rofi/defaults.json .config/rofi/utils/defaults.json)
old+=(.config/rofi/config.rasi .config/rofi/utils/settings.json .config/rofi/icon-gen/icons/LICENSE .config/rofi/icon-gen/LICENSE)
if [[ -d $HOME/.config/rofi/utils ]]; then
    while IFS= read -r -d '' path; do old+=("${path#"$HOME/"}"); done < <(find "$HOME/.config/rofi/utils" -type f -print0)
fi
# Include the retired backend in rollback before removing its installed files.
if [[ -d $HOME/.config/dots-utils ]]; then
    while IFS= read -r -d '' path; do old+=("${path#"$HOME/"}"); done < <(find "$HOME/.config/dots-utils" -type f -print0)
fi
for name in autocorrect bluetooth calc clipboard keybinds media power-mode power wifi windows; do old+=(".config/rofi/$name.sh"); done
for name in core.py launcher.py service.py launcher.sh common.sh ai.sh time.sh worker.sh tray.sh; do old+=(".config/rofi/hub/$name"); done
# Include personal icon sources/outputs in rollback even if absent in the snapshot.
extra=()
if [[ -d $HOME/.config/rofi/icons ]]; then
    while IFS= read -r -d '' path; do
        old+=("${path#"$HOME/"}")
        extra+=(".config/rofi/icon-gen/icons/${path##*/}")
    done < <(find "$HOME/.config/rofi/icons" -maxdepth 1 -type f -print0)
fi
for directory in "$HOME/.config/rofi/hub/icons" "$HOME/.config/rofi/icon-gen/sources"; do
    [[ -d $directory ]] || continue
    for path in "$directory/"*.svg; do
        [[ -f $path ]] || continue
        extra+=(".config/rofi/icon-gen/sources/${path##*/}" ".config/rofi/icon-gen/icons/${path##*/}")
    done
done
hypr=.config/hypr/hyprland.lua
[[ -f $HOME/$hypr ]] || { printf 'Missing active Hyprland config\n' >&2; exit 1; }
grep -Eq 'rofi -terminal alacritty -show run|[.]config/rofi/(hub/)?launcher[.](py|sh)' "$HOME/$hypr" || { printf 'Launcher binding differs; inspect before applying\n' >&2; exit 1; }
mkdir -p "$HOME/dots-dev/backups"
backup=$(mktemp -d "$HOME/dots-dev/backups/rofi-layout-$(date +%Y%m%d-%H%M%S)-XXXXXX")
manifest='{"files":[],"units":[]}'
for unit in "${units[@]}"; do
    enabled=false; active=false
    if systemctl --user is-enabled --quiet "$unit"; then enabled=true; fi
    if systemctl --user is-active --quiet "$unit"; then active=true; fi
    manifest=$(jq --arg name "$unit" --argjson enabled "$enabled" --argjson active "$active" '.units += [{name:$name,enabled:$enabled,active:$active}]' <<<"$manifest")
done
backup_paths=("${files[@]}" "${old[@]}" "$hypr" .config/hypr/autostart.sh .config/systemd/user/dots-utils-clock.timer.d/deadline.conf)
if ((${#extra[@]})); then backup_paths+=("${extra[@]}"); fi
for path in "${backup_paths[@]}"; do
    existed=false
    if [[ -f $HOME/$path ]]; then existed=true; mkdir -p "$backup/${path%/*}"; cp -p "$HOME/$path" "$backup/$path"; fi
    manifest=$(jq --arg name "$path" --argjson existed "$existed" '.files += [{name:$name,existed:$existed}]' <<<"$manifest")
done
printf '%s\n' "$manifest" > "$backup/manifest.json"
printf 'Backup: %s\n' "$backup"
trap 'status=$?; if ((status)); then restore_backup "$backup" || :; fi' EXIT
stop_workers
bash "$source_dir/scripts/migrate-rofi.sh"
for path in "${files[@]}"; do
    case $path in
        */settings.json) [[ ! -f $HOME/$path ]] || continue;;
    esac
    mkdir -p "$HOME/${path%/*}"; cp -p "$source_dir/$path" "$HOME/$path"
done
bash "$HOME/.config/rofi/icon-gen/generate.sh" --offline
for path in "${old[@]}"; do rm -f -- "$HOME/$path"; done
rmdir "$HOME/.config/rofi/utils/sounds" "$HOME/.config/rofi/utils" 2>/dev/null || :
rmdir "$HOME/.config/dots-utils/sounds" "$HOME/.config/dots-utils" 2>/dev/null || :
rmdir "$HOME/.config/rofi/lib" "$HOME/.config/rofi/icons" 2>/dev/null || :
sed -E -e 's|rofi -terminal alacritty -show run|~/.config/rofi/launcher.sh|g' -e 's@rofi/hub/launcher\.(py|sh)@rofi/launcher.sh@g' -e 's|rofi/keybinds.sh|rofi/modi/keybinds.sh|g' -e 's|rofi -show power|~/.config/rofi/launcher.sh power|g' -e 's|Open dashboard (letter shortcuts)|Open Run (Tab for menu)|g' "$HOME/$hypr" > "$backup/hypr.new"
sed -e 's|hl.dsp.exec_cmd("nemo"), "Open the file manager"|hl.dsp.exec_cmd("~/.config/rofi/launcher.sh menu"), "Open the Rofi menu"|' "$backup/hypr.new" > "$HOME/$hypr"
if ! grep -q 'name = "dots-rofi"' "$HOME/$hypr"; then
    printf '\nhl.layer_rule({ name = "dots-rofi", match = { namespace = "^rofi$" }, animation = "fade", blur = true, ignore_alpha = 0.5 })\n' >> "$HOME/$hypr"
fi
if ! grep -q 'initial_class = "\^dots-files\$"' "$HOME/$hypr"; then
    printf '\nhl.window_rule({ match = { initial_class = "^dots-files$" }, float = true })\n' >> "$HOME/$hypr"
fi
autostart=$HOME/.config/hypr/autostart.sh
if [[ -f $autostart ]]; then sed -E '/(^|[^[:alnum:]_-])(dots-rofi|dots-desktop|desktop-utils|utils|dots-utils)\.service/d' "$autostart" > "$backup/autostart.new"; cat "$backup/autostart.new" > "$autostart"; fi
systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
reload
bash "$HOME/.config/rofi/modi/time.sh" reconcile
printf 'Applied rofi layout and native clock scheduling; settings and clocks preserved.\n'

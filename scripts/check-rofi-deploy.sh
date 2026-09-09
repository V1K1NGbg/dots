#!/usr/bin/env bash
# Isolated deployment/rollback regression test; desktop commands are stubbed.
set -euo pipefail
repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
export HOME=$scratch/home XDG_CONFIG_HOME=$scratch/home/.config XDG_STATE_HOME=$scratch/home/.local/state XDG_CACHE_HOME=$scratch/cache XDG_RUNTIME_DIR=$scratch/runtime
mkdir -p "$HOME/.config/rofi/hub" "$HOME/.config/hypr" "$HOME/.config/systemd/user" "$XDG_STATE_HOME/dots-rofi" "$scratch/bin"
mkdir -p "$HOME/.config/rofi/lib" "$HOME/.config/rofi/icons"
printf 'old AI helper\n' > "$HOME/.config/rofi/lib/ai.sh"
cp "$repo/.config/rofi/icon-gen/icons/bot.svg" "$HOME/.config/rofi/icons/bot.svg"
printf '{"items":[{"id":"legacy","kind":"timer","label":"Keep me","due":null}],"alerts":[],"watch":{}}' > "$XDG_STATE_HOME/dots-rofi/clocks.json"
printf '{"icon_color":"#123456","weather":{"city":"Custom city"}}' > "$HOME/.config/rofi/hub.json"
printf 'legacy launcher\n' > "$HOME/.config/rofi/hub/launcher.sh"
printf 'legacy unit\n' > "$HOME/.config/systemd/user/dots-rofi.service"
printf 'legacy desktop unit\n' > "$HOME/.config/systemd/user/dots-desktop.service"
printf 'legacy utils unit\n' > "$HOME/.config/systemd/user/utils.service"
printf 'exec("~/.config/rofi/hub/launcher.sh")\nexec("~/.config/rofi/keybinds.sh")\n' > "$HOME/.config/hypr/hyprland.lua"
printf 'exec("rofi -show power")\n' >> "$HOME/.config/hypr/hyprland.lua"
printf 'start dots-rofi.service\n' > "$HOME/.config/hypr/autostart.sh"
printf 'start dots-desktop.service\n' >> "$HOME/.config/hypr/autostart.sh"
printf 'start utils.service\n' >> "$HOME/.config/hypr/autostart.sh"
printf 'modi: "window:/home/victor/.config/rofi/windows.sh";\ncustom_setting: true;\n' > "$HOME/.config/rofi/config.rasi"
cat > "$scratch/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
case $1 in instances) printf '[{"instance":"test","wl_socket":"wayland-1"}]';; configerrors) :;; *) printf ok;; esac
STUB
cat > "$scratch/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HOME/systemctl.log"
STUB
for cmd in fd fzf alacritty flock timeout busctl pactl wpctl pw-play notify-send code playerctl; do printf '#!/usr/bin/env bash\nexit 0\n' > "$scratch/bin/$cmd"; done
printf '#!/usr/bin/env bash\nprintf "blocks\\n"\n' > "$scratch/bin/rofi"
chmod +x "$scratch/bin/"*
export PATH=$scratch/bin:$PATH
bash "$repo/scripts/deploy-rofi.sh" "$repo" > "$scratch/deploy.log"
backup=$(sed -n 's/^Backup: //p' "$scratch/deploy.log")
[[ -n $backup && -f $HOME/.config/rofi/modi/time.sh && ! -f $HOME/.config/rofi/hub/launcher.sh ]]
[[ -f $HOME/.config/rofi/modi/common.sh && -f $HOME/.config/rofi/modi/ai.sh ]]
[[ ! -d $HOME/.config/rofi/lib && ! -d $HOME/.config/rofi/icons ]]
[[ -f $HOME/.config/systemd/user/dots-utils-clock.timer && ! -f $HOME/.config/systemd/user/dots-rofi.service ]]
[[ ! -f $HOME/.config/systemd/user/dots-desktop.service ]]
[[ ! -f $HOME/.config/systemd/user/utils.service ]]
if grep -Eq '(^|[[:space:]])utils.service' "$HOME/.config/hypr/autostart.sh"; then exit 1; fi
grep -q 'rofi/launcher.sh' "$HOME/.config/hypr/hyprland.lua"
grep -q 'rofi/modi/keybinds.sh' "$HOME/.config/hypr/hyprland.lua"
[[ ! -f $HOME/.config/rofi/config.rasi ]]
grep -q 'rofi/launcher.sh power' "$HOME/.config/hypr/hyprland.lua"
! grep -q dots-utils.service "$HOME/.config/hypr/autostart.sh"
grep -q '#123456' "$HOME/.config/rofi/icon-gen/icons/bot.svg"
jq -e '.weather.city=="Custom city"' "$HOME/.config/rofi/settings.json" >/dev/null
jq -e '.weather.latitude!=null' "$HOME/.config/rofi/settings.json" >/dev/null
jq -e '(.exclude|type)=="array"' "$HOME/.config/rofi/settings.json" >/dev/null
jq -e '.ai_url!=null and .icon_color=="#123456"' "$HOME/.config/rofi/settings.json" >/dev/null
[[ ! -f $HOME/.config/rofi/defaults.json && ! -f $HOME/.config/rofi/utils/defaults.json ]]
jq -es '.[0]==.[1]' "$XDG_STATE_HOME/dots-rofi/clocks.json" "$XDG_STATE_HOME/dots-utils/clocks.json" >/dev/null
bash "$repo/scripts/deploy-rofi.sh" --restore "$backup" > "$scratch/restore.log"
[[ ! -f $HOME/.config/rofi/launcher.sh && ! -f $HOME/.config/systemd/user/dots-utils.service ]]
grep -q 'legacy launcher' "$HOME/.config/rofi/hub/launcher.sh"
grep -q 'custom_setting: true' "$HOME/.config/rofi/config.rasi"
grep -q 'rofi -show power' "$HOME/.config/hypr/hyprland.lua"
grep -q 'old AI helper' "$HOME/.config/rofi/lib/ai.sh"
cmp "$repo/.config/rofi/icon-gen/icons/bot.svg" "$HOME/.config/rofi/icons/bot.svg"
grep -q 'legacy unit' "$HOME/.config/systemd/user/dots-rofi.service"
grep -q 'legacy desktop unit' "$HOME/.config/systemd/user/dots-desktop.service"
grep -q 'legacy utils unit' "$HOME/.config/systemd/user/utils.service"
grep -q dots-rofi.service "$HOME/.config/hypr/autostart.sh"
printf 'PASS: isolated selected deployment, legacy migration, preserved settings, bindings and configuration rollback\n'

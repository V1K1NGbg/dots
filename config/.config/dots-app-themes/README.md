# Discord and Spotify themes

Run **Copy dotfiles**, then **Set up Discord + BetterDiscord** and
**Set up Spotify + Spicetify** in `install.sh`. Discord must finish its first
launch before continuing setup. Account login remains manual.

Each task installs a Pacman hook under `/etc/pacman.d/hooks/95-dots-*-theme.hook`
for the installing user and applies the theme once. After `paru` or Pacman installs
or upgrades `discord` or `spotify-launcher`, the corresponding hook starts
`dots-app-theme@discord.service` or `dots-app-theme@spotify.service` as that user.
The package transaction does not wait for theme downloads. No timers or recurring
checks run. See [Pacman's hook documentation](https://man.archlinux.org/man/alpm-hooks.5.en).

Spotify uses `spotify-launcher`, whose package is separate from the actual client.
The Spotify service runs `spotify-launcher --check-update --no-exec` first, then
reapplies Spicetify if the client files need it. It reads the installed binary's
version for patching, so a new client does not need to launch first. Spicetify's
normal prefs path is restored on exit; account preferences are never rewritten.
See the [launcher's options](https://github.com/kpcyrd/spotify-launcher/blob/main/src/args.rs).

The installed `apply.sh` downloads the latest official
[BetterDiscord CLI](https://github.com/BetterDiscord/cli) or
[Spicetify](https://github.com/spicetify/cli) release when repair is needed and
checks the archive against GitHub's SHA-256 digest before running it.
BetterDiscord's CLI also downloads the latest BetterDiscord.

This targets x86_64 Arch's native Discord with `~/.config/discord/app-*/resources`
and `spotify-launcher` with its user-owned installation under
`~/.local/share/spotify-launcher/install/usr/share/spotify`. Patching runs without
root permissions. Other packaging layouts are not handled.

Discord may restart when BetterDiscord is injected. Spotify is patched without
interrupting playback; an open window uses the theme after its next restart.
Updates performed by the applications themselves, outside a package transaction,
do not trigger these hooks. Run the corresponding service manually after those
updates or after a failed attempt (for example, when offline or the launcher is busy):

```sh
systemctl --user start dots-app-theme@discord.service
systemctl --user start dots-app-theme@spotify.service
journalctl --user -u dots-app-theme@spotify.service
```

Theme defaults are `BetterDiscord/themes/neutron.theme.css` and
`spicetify/Themes/Ziro/{color.ini,user.css}` under `~/.config`. They mirror
Alacritty's charcoal background, cyan/blue accents and Monocraft Nerd Font.
Ziro's CSS comes from [schnensch0/ziro](https://github.com/schnensch0/ziro).
The playing icon credits CharlieS and harbassan. There is no wallpaper or
Marketplace dependency.

To stop automatic reapplication, remove the two `95-dots-*-theme.hook` files from
`/etc/pacman.d/hooks`. With both applications closed, remove customization with:

```sh
~/.local/share/dots-app-themes/discord/bdcli uninstall --channel stable
~/.local/share/dots-app-themes/spotify/spicetify restore --no-restart
```

Spicetify refuses incompatible backups; do not force an old backup over a newer
client. Dotfile setup backs up replaced configuration as described in the root
README. Discord theme selection is backed up under
`~/.local/share/archinstaller/discord-themes.*.json` when present.

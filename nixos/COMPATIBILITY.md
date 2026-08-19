# Desktop compatibility decisions

| Goal/tool | Current implementation | Status |
| --- | --- | --- |
| Boot authentication | LUKS2 root unlock through Hexagon HUD Plymouth | Only boot-time prompt |
| Desktop login | tty1 autologin followed by UWSM | No display manager |
| Window management | Hyprland `dwindle` tiling | Enabled |
| Displays | Preferred mode, automatic placement, scale 1 | No machine-specific layout |
| Wallpaper | Solid color through `swaybg` | Started with Hyprland |
| Borders and gaps | Native Hyprland settings | Enabled |
| Animations | Window, fade, and workspace animations | Enabled |
| Launcher | Rofi `drun` | `Super+R` |
| Terminal | Alacritty | `Super+Enter` |
| Keyboard | US layout | No secondary layout configured |
| Touchpad | Natural scrolling | Enabled |
| Status bar | Waybar package and config retained | Not started automatically |
| Lock and idle | Hyprlock and Hypridle packaged/configured | Not started automatically |
| Notifications | Mako package and Monocraft config | Not started automatically |
| Night colour | Hyprsunset packaged/configured | Not started automatically |
| Screenshots | Grim, Slurp, Satty, and Flameshot installed | No compositor shortcut |
| Discord, Spotify, pCloud, GLava | XWayland remains available | Test individually |
| CopyQ | Package retained | Manual state import |
| llama.cpp | Native package with Vulkan acceleration | User-managed GGUF models |

Monocraft Nerd Font is the fontconfig default for serif, sans-serif, and
monospace text. Managed GTK, Alacritty, Rofi, Waybar, Hyprlock, Mako, Firefox,
and VS Code settings select it explicitly. Applications and websites that ship
or request their own fonts can still override the system default.

Anyone who knows the disk passphrase receives the `victor` desktop session
without a second login prompt. The account password remains required for
privilege elevation and any explicitly locked session.

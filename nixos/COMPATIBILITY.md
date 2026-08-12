# Hyprland compatibility decisions

| Goal/tool | Hyprland implementation | Status |
| --- | --- | --- |
| Window management | Native Hyprland Lua configuration | Primary desktop |
| Status bar | Waybar | Declarative |
| Lock and idle | Hyprlock + Hypridle | Declarative, fingerprint-enabled |
| Notifications | Mako | Declarative package and session startup |
| Monitor layouts | Runtime Lua rules matched by connector and panel description | Covers known laptop panels and MSI display |
| Keyboard layouts | Hyprland `us,bg` with Bulgarian phonetic variant | Super+Space toggle |
| Touchpad gestures | Native Hyprland workspace gesture | Three-finger horizontal |
| Screenshots | Grim + Slurp + Satty | Super+P |
| Night colour | Hyprsunset | Started with the session |
| Fusuma | Nixpkgs bundle with the sendkey plugin | Parsed by a build check |
| Discord, Spotify, pCloud, GLava | XWayland where native Wayland is unavailable | XWayland intentionally enabled |
| Flameshot | Installed for retained workflows | Grim/Slurp/Satty is the native shortcut |
| CopyQ | Retained; test clipboard behavior under Wayland | Manual state import remains available |
| Ollama | Docker by default, native Vulkan optional | See `machine.nix` |

Mutable application settings are seeded only when absent, so later rebuilds do
not overwrite changes made through application interfaces.

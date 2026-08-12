# Compatibility and replacement matrix

This matrix is based on the exact NixOS 26.05 revision in `flake.lock`, not on a
search of the moving unstable channel. `packages.nix` distinguishes required
daily-driver packages from optional ones. Missing required packages are an
evaluation error.

| Existing goal/tool | Awesome/X11 profile | Optional Hyprland profile | Decision |
| --- | --- | --- | --- |
| AwesomeWM + `lain` | Native and default | Still installed and selectable | Preserve until the trial passes |
| Picom animations | Exact `picom-pijulius` package; no unsafe fallback | Not used | Required on Awesome |
| Firefox, VS Code, Nemo, KeePassXC | Native nixpkgs packages | Native Wayland where supported, otherwise XWayland | Required |
| Discord + BetterDiscord | Discord is packaged; BetterDiscord injection remains manual | XWayland available; retest injection, updates and screen sharing | Do not declare parity until tested |
| Spotify launcher | Replaced by the official `spotify` nixpkgs package | Same package, XWayland allowed | Goal preserved with a different launcher |
| pCloud | Native nixpkgs package | XWayland available; tray and sync need testing | Required |
| CopyQ | Native package and writable settings | XWayland available; clipboard/global shortcuts need testing | Required, verify full behavior |
| VTop | Not present in this nixpkgs release | `btop` replacement | Same monitoring goal, actively maintained package |
| NVM + global Node tools | A pinned Node.js and the used language tools are installed from nixpkgs | Same | Prefer project-specific `nix develop`; restore NVM only for an otherwise unavailable Node version |
| Cloudflare DNS | `1.1.1.1` and `1.0.0.1` remain explicit system resolvers | Same | Preserved from the working setup |
| WireGuard | NetworkManager supports it natively; connection profiles remain private mutable state | Same | Import the backed-up profile during onboarding; never commit it |
| Fusuma sendkey plugin | Pinned `fusuma` includes `fusuma-plugin-sendkey` 0.14.0 and `revdev`; the original `sendkey:` mappings are restored | Native Hyprland gesture | Required and build-checked; still verify the physical keyboard device match on the laptop |
| Arandr/Autorandr | Preserved | X11-only; Hyprland Lua monitor rules cover known panels | Keep for Awesome only |
| Flameshot | Preserved | Grim + Slurp + Satty key binding | Native Wayland replacement for capture/edit |
| Redshift | Preserved in Awesome startup | Hyprsunset profiles | Native Wayland replacement |
| GLava | Native X11 | XWayland may open it, but desktop-layer behavior is uncertain | Optional; test before deciding |
| Steam | NixOS module with 32-bit graphics | Same with XWayland | Required workflow, test games/controllers individually |
| AppImages/foreign binaries | AppImage binfmt and `nix-ld` enabled | Same | Escape hatch, not a reproducibility guarantee |
| Apps absent from nixpkgs | Flatpak service and portals enabled | Hyprland + GTK portals selected explicitly | Prefer verified upstream/Flathub sources; document each exception |
| Plymouth Hexagon HUD | Built from an immutable, hashed upstream input | Same | Reproduced declaratively |
| Oh My Bash | Existing vendored tree managed in the home profile | Same | Avoids an unpinned install-time download |
| Ollama | Docker backend preserves the current layout; API is localhost-only | Same | Switch to pinned native Vulkan service only after model migration |

## Mutable data that Nix does not own

The following must be backed up and migrated separately: KeePass databases,
browser profiles, credentials and tokens, WireGuard/SSH/GPG keys, Docker named
volumes, Ollama models, pCloud local-only data, application accounts, game
saves, and untracked files. Home Manager manages defaults and code, not these
data sets.

BetterDiscord JSON, KeePassXC INI, Flameshot preferences, and GTK bookmarks are
seeded only when absent. Nemo and CopyQ exports are manual imports. This
prevents a rebuild from reverting normal application changes.

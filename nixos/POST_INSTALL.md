# Post-install application setup

This guide starts after the `dots` NixOS configuration has been installed. It
keeps reproducible settings in Nix and leaves credentials, tokens, device
registrations, and application databases out of Git.

## 1. Build and activate safely

From the repository root:

```sh
nix flake check --no-build
sudo nixos-rebuild boot --flake .#dots
sudo reboot
```

Log in through tuigreet, open Alacritty with `Super+Enter`, then run:

```sh
cd ~/dots
nix run .#onboard
systemctl --failed
systemctl --user --failed
```

Use `Super+R` to open Rofi. If the new boot generation is broken, select the
previous generation in the systemd-boot menu.

## 2. pCloud Drive

The pCloud package, local folders, and graphical-session startup are
declarative. Account authentication and Sync/Backup mappings are pCloud state
and must be configured once in its UI.

1. Start pCloud manually the first time with `pcloud` if it is not already open.
2. Sign in to the existing pCloud account and complete any two-factor prompt.
3. Leave pCloud's own **start on system startup** option disabled; the
   declarative user service already handles startup and avoids duplicate clients.
4. Confirm that `pCloudDrive` appears in Nemo and that files can be listed.
5. Open **Sync**, choose **Add New Sync**, select `~/Documents/PC` locally, and
   select or create `/PC` in pCloud.
6. Open **Backup**, add `~/Documents/BackUp`, and wait for the initial scan.
7. Log out and back in once. Confirm startup with:

   ```sh
   systemctl --user status pcloud.service
   ```

Do not commit pCloud's profile, tokens, cache, mounted-drive state, or database.
The systemd user service only starts the client after graphical login; it does
not bypass authentication or invent sync mappings.

## 3. Firefox

Firefox, default-browser MIME associations, and Monocraft default fonts are
declarative. Mozilla account authentication and synced personal data remain
manual.

1. Start Firefox from Rofi.
2. Open the application menu and choose **Sign in** or **Sync and save data**.
3. Sign in to the Mozilla account and complete email or two-factor verification.
4. Under **Settings → Sync**, select the desired categories: bookmarks,
   passwords, history, open tabs, add-ons, and settings.
5. Wait for Sync to finish before importing local exports, to avoid duplicates.
6. Install Vimium and Bonjourr if Sync did not restore them.
7. In Vimium's options, import:
   `~/.local/share/dots/imports/vimium-options.json`.
8. In Bonjourr's settings, import:
   `~/.local/share/dots/imports/bonjourr-20.4.2.json`.
9. Visit `about:policies` and `about:config` if you want to confirm that the
   Nix-managed default font preferences are active.

Firefox Sync is the appropriate declarative-like mechanism for personal browser
state, but it is intentionally tied to an authenticated Mozilla account rather
than stored in this public repository. Extensions could be force-installed with
Firefox enterprise policies, but that would lock installation policy to AMO IDs
and is not enabled here.

## 4. VS Code

The package and Monocraft editor, terminal, debug-console, and chat fonts are
declarative. The managed settings file is read-only, so do not ask Settings Sync
to overwrite it.

1. Start VS Code and open the Accounts menu.
2. Choose **Turn on Settings Sync** and authenticate with GitHub or Microsoft.
3. In **Configure Sync**, leave **Settings** disabled; enable extensions,
   keyboard shortcuts, snippets, UI state, and profiles as desired.
4. Wait for extensions to install and restart VS Code if requested.

Additional VS Code settings should be added to
`.config/Code/User/settings.json` in this repository.

## 5. Git and GitHub

Git name and email are declarative. GitHub authentication is a secret-bearing
device authorization and remains manual.

```sh
gh auth login
gh auth status
ssh -T git@github.com
```

Choose the desired protocol during `gh auth login`. SSH private keys and GitHub
tokens must not be committed. A future declarative secret setup should use
`sops-nix`, `agenix`, or a hardware-backed credential store.

## 6. WireGuard VPN

NetworkManager and WireGuard support are declarative; the private-key-bearing
connection is not stored in this repository.

```sh
nmcli connection import type wireguard file /path/to/profile.conf
nmcli connection modify PROFILE_NAME connection.autoconnect no
nmcli connection up PROFILE_NAME
```

Confirm the public IP and DNS behavior, then securely remove the temporary
profile file if it was copied from removable media. Fully declarative WireGuard
is possible after adding encrypted secret management; never place a raw private
key in a tracked `.nix` file.

## 7. KeePassXC

The repository seeds preferences only when no preferences file exists. The
password database and its unlock material remain manual.

1. Open KeePassXC.
2. Open the existing `.kdbx` database from its restored location.
3. Configure the key file or hardware key, if used.
4. Enable browser integration only after installing the KeePassXC-Browser
   extension in Firefox and pairing it with the database.
5. Back up the database independently; never commit it or its key file.

## 8. CopyQ and Nemo

These applications own mutable state, so their exports are staged rather than
linked into read-only Nix-store paths.

Import CopyQ history and settings deliberately:

```sh
copyq importData ~/.local/share/dots/imports/copyq.cpq
```

Review the Nemo export, then apply it:

```sh
dconf load /org/nemo/ < ~/.local/share/dots/imports/nemo_config
```

Restart each application and verify the result. Re-importing can duplicate or
overwrite mutable state, so these commands are not run automatically.

## 9. Discord, BetterDiscord, Spotify, and Steam

The applications are installed declaratively. Sign-ins, device authorization,
downloaded game data, and DRM state remain manual.

1. Start each application from Rofi and sign in.
2. Complete any email, authenticator, or device confirmation.
3. For Steam, select or recreate library folders and let cloud saves synchronize
   before launching games.
4. BetterDiscord plugin and theme code in this repository is linked
   declaratively; mutable plugin JSON is seeded only when missing.
5. BetterDiscord itself patches Discord and may break after Discord updates, so
   installation of the patcher remains an explicit manual choice.

Do not commit Discord tokens, Spotify cookies, Steam credentials, or application
cache directories.

## 10. Fingerprints

Fingerprint services and PAM integration are declarative. Fingerprints are
hardware-local biometric records and must be enrolled on the machine:

```sh
fprintd-enroll
fprintd-verify
```

Test `sudo` and Hyprlock while a password login path is still available.

## 11. llama.cpp

The Vulkan-enabled llama.cpp build is declarative. GGUF model files are large,
mutable data and are not part of the Nix store or Git repository.

```sh
llama-cli --model /path/to/model.gguf --prompt "Hello"
llama-server --model /path/to/model.gguf --host 127.0.0.1 --port 8080
```

Keep the server bound to `127.0.0.1` unless LAN exposure is intentional and the
firewall/authentication design has been reviewed.

## Declarative boundary summary

| Item | Declarative now | Manual or secret state |
| --- | --- | --- |
| Fonts and desktop defaults | NixOS/Home Manager | App-specific overrides |
| pCloud | Package, folders, startup | Login, Sync and Backup mappings |
| Firefox | Package, MIME defaults, font preferences | Account, Sync data, extension imports |
| VS Code | Package and font settings | Account and selected Sync categories |
| Git/GitHub | Git identity | Tokens, SSH private keys, device login |
| WireGuard | Network stack | Private key and connection profile |
| KeePassXC | Initial preferences | Database and unlock factors |
| CopyQ/Nemo | Export staging | One-time mutable import |
| Media/chat/game apps | Packages | Accounts, caches, libraries, DRM |
| Fingerprints | PAM/services | Hardware enrollment |
| llama.cpp | Vulkan-enabled binary | GGUF models and server invocation |

The remaining manual pieces can only become safely declarative after adding an
encrypted secret-management system. Plaintext credentials do not belong in this
repository or in the Nix store.

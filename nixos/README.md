# NixOS conversion

This flake converts the checked-in Arch installer and dotfiles into the `dots`
NixOS configuration. It uses only files in the current checkout. All tracked
desktop configuration directories are installed by Home Manager; the vendored
AwesomeWM `lain` tree, icons, BetterDiscord plugins, OpenCode agents/scripts,
GLava shaders, and monitor profiles are therefore preserved byte-for-byte.

## Install

Boot the official minimal NixOS image in UEFI mode. Connect it to the network,
partition the disk, mount the root filesystem at `/mnt`, and mount the EFI
system partition at `/mnt/boot`. From this repository, run:

```sh
sudo ./nixos/install-from-minimal.sh /mnt
```

The installer checks the mounts and UEFI mode, generates the target-specific
`hardware-configuration.nix`, locks and evaluates the path-based flake, runs
`nixos-install`, and asks for passwords for both root and `victor`. The path
flake form is intentional: it also works when the newly created Nix files have
not been committed yet.

`hardware-configuration.nix` is generated rather than fabricated because its
filesystems, swap, and initrd storage drivers must match the target machine.
If the repository already contains a different hardware configuration, the
script saves it as `hardware-configuration.nix.pre-install-backup` first.

For a non-UEFI machine or an EFI partition mounted somewhere other than
`/boot`, adjust the boot-loader module and install manually instead of using
the helper.

After edits, validate and apply with:

```sh
nix flake check
sudo nixos-rebuild switch --flake .#dots
```

When the new files are still uncommitted in a Git checkout, use a path flake:

```sh
nix flake check "path:$PWD"
sudo nixos-rebuild switch --flake "path:$PWD#dots"
```

## Exact and non-declarative state

- AwesomeWM needs a private `const.lua` for the OpenWeatherMap APPID and
  coordinates. Home Manager creates a harmless empty placeholder. Put real
  values in a private module or secret manager; do not commit them.
- Nemo's complete dconf dump is installed at
  `~/.local/share/dots/imports/nemo_config` and a user service applies it at
  graphical login. It can also be reapplied manually with:

  ```sh
  dconf load /org/nemo/ < ~/.local/share/dots/imports/nemo_config
  ```

- CopyQ, Vimium, both Bonjourr snapshots, and marketplace settings are placed
  under `~/.local/share/dots/imports/` for their applications' import dialogs.
- GitHub authentication, WireGuard keys, fingerprint enrollment, Firefox/VS
  Code sync, Discord/Spotify/pCloud login, and BetterDiscord injection are
  account-, device-, or secret-specific and still require interactive setup.
- The old installer fetched the latest Node through NVM. Nix installs its
  pinned `nodejs` package instead. OpenCode's formatter and LSP commands are
  installed explicitly.
- The repository requests the pijulius Picom animation fork. The package map
  prefers `picom-pijulius` and falls back to upstream `picom`; evaluation emits
  warnings for packages with no equivalent in the selected nixpkgs revision.
- Fusuma is installed and the user belongs to `input`; if the nixpkgs Fusuma
  build does not include the `sendkey` plugin, install/package that Ruby plugin
  before enabling the checked-in gesture actions.
- The AUR Plymouth `hexagon_hud` theme is not reproduced without a pinned,
  hashed source. Plymouth itself, quiet boot, splash, and the AMD kernel option
  are enabled.

## Package mapping notes

NixOS modules replace Arch packages for Docker, Steam, Bluetooth, NetworkManager,
fprintd, Xorg/AwesomeWM, graphics/Vulkan, PipeWire/ALSA, dconf, and Plymouth.
`packages.nix` contains every remaining package from `install.sh`, plus commands
found only in configs: `xsel`, `libqalculate`, `iputils`, Oh My Bash, OpenCode,
Node, VTop, Python, Prettier, Black, Clang tools, shfmt, Rust Analyzer/rustfmt,
Go/gopls, Pyright, and TypeScript Language Server.

The Ollama compose definition is translated into a boot-managed Docker
container with the same ports, volume, AMD devices, resource limits,
environment, and ulimits. The original compose file is also retained at
`~/.local/share/dots/docker-compose.yml` for inspection or manual use.

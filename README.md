# dots

##### ***!Disclaimer: the install script is more of a general guideline for installing rather than a concrete script!***

## OpenCode

See [the OpenCode guide](.config/opencode/README.md) for agents, slash commands,
the local model, permission behavior, and configuration validation.

## Development on the test laptop

Edit this checkout on the development computer. The Arch test laptop is
`victor@192.168.1.177`, with its installed repository at `~/dots`.
SSH uses the dedicated local key `~/.ssh/dots_laptop`; private keys and passwords
must never be added to this repository.

From this checkout, using Python 3:

```sh
python3 scripts/laptop-dev.py check
python3 scripts/laptop-dev.py sync
```

`sync` prints a fresh snapshot path under the laptop's `~/dots-dev/`.
It includes tracked working-tree edits and new non-ignored files, omits deleted
files, and leaves `~/dots` and the active desktop configuration untouched.
Tracked files remain included even if they match an ignore rule. Review new
files before syncing. Each snapshot is retained for comparison and can be
removed manually when no longer needed. SSH and tar are required on the laptop;
rsync is not required. Override the connection with `--host` and `--identity`.

Read actual laptop files and run checks directly over SSH:

```sh
ssh -i ~/.ssh/dots_laptop -o IdentitiesOnly=yes victor@192.168.1.177
```

In that session, inspect the printed snapshot and validate the component being
changed. The installer copies files into the home directory, so syncing a
snapshot does not activate it. Back up the affected active files before copying
the selected configs from the snapshot, then reload the relevant application.
Do not run the full installer for every config edit. Keep all resulting fixes
in the development checkout, including any necessary installation changes.
Do not copy the laptop's entire home directory back into Git.

## Releases

Use Git commits for development and annotated tags `v1.2.0`, `v1.2.1`, and so on
for tested releases. The existing commit titled `v1.2` has no corresponding tag;
the first new tested release can be `v1.2.0`. Record changes and laptop validation
in `CHANGELOG.md` before committing. Tag only after the committed contents have
been tested and the working tree is clean:

```sh
git tag -a v1.2.0 -m 'Release v1.2.0'
```

Push the release commit and its tag to the shared Git remote when ready to
publish. On the laptop, fetch that tag into `~/dots`, check that its working tree
is clean, and switch to the tag with `git switch --detach v1.2.0`. Apply the tested
configs there as needed. A tag records repository contents; it does not restore
active home-directory configs, which require their own backups.

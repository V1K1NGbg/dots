# Development and laptop testing

The user develops this repository on this computer and tests it on an Arch
Linux laptop installed from this repository. Use this workflow by default in
future sessions when making changes that need Arch or desktop validation.

## Connection

- Laptop: `victor@192.168.1.177`
- Installed repository on laptop: `/home/victor/dots`
- Test snapshots: `/home/victor/dots-dev/snapshot.*`
- Local SSH identity: `~/.ssh/dots_laptop`
- SSH key access was verified on 2026-09-06.

Use `-i ~/.ssh/dots_laptop -o IdentitiesOnly=yes -o BatchMode=yes` for SSH.
The user does not want to share a password. Never ask them to send one, read
private key contents, or put credentials in this repository. If access fails,
report the actual error and let the user perform any required authentication
locally. Respect the runtime's network and filesystem approval requirements.

## Default workflow

1. Inspect local Git status and preserve existing user changes. Keep all source,
   configuration, installer, and testing-workflow changes in this repository.
2. For relevant laptop testing, run `python3 scripts/laptop-dev.py check` and
   `python3 scripts/laptop-dev.py sync`. The latter prints the fresh snapshot
   directory. It includes tracked edits and new non-ignored files. Review the
   transfer contents for unintended files first.
3. Use SSH to read relevant active configs and logs and run appropriate checks
   against the snapshot. The user wants this connection used automatically for
   relevant development work; do not ask again merely to inspect files, sync a
   snapshot, or run ordinary non-destructive checks.
4. The installer copies configs to the home directory. Syncing a snapshot does
   not activate it. When applying configs is within the requested task, back up
   the affected active files, apply only the selected changes, and reload the
   relevant application. Do not rerun the full installer for routine edits.
   Handle disruptive actions according to the current task's authorization.
5. Preserve the laptop's `~/dots` checkout during snapshot testing. Bring any
   fixes made on the laptop back into this development checkout before release.
   Do not overwrite unrelated laptop-specific settings or bulk-copy its home
   directory into Git.
6. Report what was tested and any validation that could not be completed.

## Versioning

The user wants tested releases recorded in Git as `v1.2.x` versions, using
annotated tags and `CHANGELOG.md`. Inspect existing local and available remote
tags before choosing the next version. At setup, both checkouts were clean at
`68ac0e7` (commit title `v1.2`) and no local tags existed; this is historical
context, not an instruction to reset either checkout.

Keep development changes in the repository and update the changelog. Do not
claim a release exists until its commit and tag actually exist. Tag only tested,
committed contents with a clean working tree. Publishing commits/tags and
updating the laptop's installed checkout must follow the current task scope;
this workflow preference alone is not an instruction to publish every edit.

See `README.md` for usage and release details.

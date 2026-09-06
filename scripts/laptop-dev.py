#!/usr/bin/env python3
"""Send a working-tree snapshot to the test laptop using SSH and tar."""

import argparse
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("check", "sync"))
    parser.add_argument("--host", default="victor@192.168.1.177")
    parser.add_argument("--identity", default="~/.ssh/dots_laptop")
    args = parser.parse_args()
    if args.host.startswith("-"):
        parser.error("host must not start with '-'")
    root = Path(__file__).resolve().parent.parent
    ssh = ["ssh", "-i", os.path.expanduser(args.identity),
           "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes",
           "-o", "ConnectTimeout=10", args.host]
    if args.action == "check":
        subprocess.run(ssh + [
            'set -eu; printf "SSH connected\\n"; '
            'git -C "$HOME/dots" status --short; '
            'git -C "$HOME/dots" log -1 --oneline; command -v tar'
        ], check=True)
        return

    # Include tracked edits and new, non-ignored files; never send .git or
    # unrelated ignored machine-local files. Missing files represent deletions.
    names = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=root,
    ).split(b"\0")
    with tempfile.TemporaryFile() as archive:
        with tarfile.open(fileobj=archive, mode="w", dereference=False) as tar:
            for name in sorted(set(names) - {b""}):
                relative = os.fsdecode(name)
                path = root / relative
                if path.is_symlink() or path.is_file():
                    tar.add(path, arcname=relative, recursive=False)
                elif path.exists():
                    raise SystemExit(f"Unsupported snapshot entry: {relative}")
        archive.seek(0)
        subprocess.run(ssh + [
            'set -eu; umask 077; mkdir -p "$HOME/dots-dev"; '
            'snapshot=$(mktemp -d "$HOME/dots-dev/snapshot.XXXXXXXX"); '
            'tar -xf - -C "$snapshot"; printf "%s\\n" "$snapshot"'
        ], stdin=archive, check=True)


if __name__ == "__main__":
    main()

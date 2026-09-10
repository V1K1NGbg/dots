#!/usr/bin/env python3
"""Apply only the Rofi menu-selection helper, preserving other active settings."""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    source = (ROOT / '.config/rofi/modi/common.sh').read_text()
    target = Path.home() / '.config/rofi/modi/common.sh'
    active = target.read_text()
    start, end = 'choose() {', '\nprompt() {'
    updated = active[:active.index(start)] + source[source.index(start):source.index(end)] + active[active.index(end):]
    subprocess.run(['bash', '-n'], input=updated, text=True, check=True)
    backup = Path(tempfile.mkdtemp(prefix='rofi-selection-backup.', dir=Path.home() / 'dots-dev'))
    shutil.copy2(target, backup / 'common.sh')
    target.write_text(updated)
    print('Backup:', backup)
    print('Applied launcher selection; takes effect the next time the menu opens.')


if __name__ == '__main__':
    main()

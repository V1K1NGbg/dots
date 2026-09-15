#!/usr/bin/env python3
"""Check the Bash font installer in a temporary tree; never change active settings."""
import os
from pathlib import Path
import struct
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
installer = (root / 'install.sh').read_text()
assert 'DOTS_FONTS_PY' not in installer
for family in ('sans-serif', 'serif', 'monospace', 'Arial', 'Adwaita Sans'):
    actual = subprocess.check_output(['fc-match', '-f', '%{family}', family], text=True)
    assert 'Monocraft Nerd Font' in actual, (family, actual)
assert 'Emoji' in subprocess.check_output(['fc-match', '-f', '%{family}', 'emoji'], text=True)
source = subprocess.check_output(['fc-match', '-f', '%{file}', 'Monocraft Nerd Font'], text=True)

with tempfile.TemporaryDirectory(prefix='dots-font-check.') as directory:
    temporary = Path(directory)
    env = os.environ.copy()
    env['HOME'] = str(temporary / 'home')
    subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', r'''
source "$1/install.sh"
FONT_STAGE=$2/work
FONT_BACKUP=$2/backup
mkdir -p "$FONT_STAGE" "$FONT_BACKUP"
# Exercise real INI writes, including several changes to the same file.
printf '# retained comment\n[Other]\nuntouched=yes\n[Fonts]\nfixed=old\ngeneral=old\n' > "$2/qt.ini"
cp "$2/qt.ini" "$2/original.ini"
font_ini "$2/qt.ini" Fonts fixed '"Monocraft Nerd Font,10"'
font_ini "$2/qt.ini" Fonts general '"Monocraft Nerd Font,10"'
cmp "$2/original.ini" "$FONT_BACKUP$2/qt.ini"
grep -Fx '# retained comment' "$2/qt.ini"
grep -Fx 'untouched=yes' "$2/qt.ini"
cp "$2/qt.ini" "$2/first.ini"
font_ini "$2/qt.ini" Fonts general '"Monocraft Nerd Font,10"'
cmp "$2/first.ini" "$2/qt.ini"
font_ini "$2/new.ini" Settings gtk-font-name 'Monocraft Nerd Font 10'
font_ini "$2/new.ini" Settings extra value
grep -Fx "$2/new.ini" "$FONT_BACKUP/created-files.txt"
[[ ! -e $FONT_BACKUP$2/new.ini ]]
# A missing final newline must not corrupt the inserted INI key.
printf '[Other]\nuntouched=yes' > "$2/no-newline.ini"
font_ini "$2/no-newline.ini" Fonts general Monocraft
grep -Fx 'untouched=yes' "$2/no-newline.ini"
grep -Fx 'general=Monocraft' "$2/no-newline.ini"
# Run the desktop task against the isolated HOME. Stub only live-session
# operations; actual Bash file edits and font matching still run.
TEST_LOG=$2/gsettings.log
gsettings() {
    case $1 in
        list-schemas) printf '%s\n' org.gnome.desktop.interface org.gnome.desktop.wm.preferences;;
        list-keys) printf '%s\n' font-name document-font-name monospace-font-name titlebar-font;;
        get) printf "'Previous Font 11'\n";;
        set) printf '%s\t%s\t%s\n' "$2" "$3" "$4" >> "$TEST_LOG";;
        *) return 1;;
    esac
}
fc-cache() { :; }
makoctl() { :; }
configure_fonts
[[ $(wc -l < "$TEST_LOG") == 4 ]]
grep -F 'Monocraft Nerd Font Bold 10' "$TEST_LOG"
grep -Fx 'gtk-font-name=Monocraft Nerd Font 10' "$HOME/.config/gtk-4.0/settings.ini"
grep -Fx 'gtk-font-name="Monocraft Nerd Font 10"' "$HOME/.gtkrc-2.0"
grep -F 'fixed="Monocraft Nerd Font,10' "$HOME/.config/qt5ct/qt5ct.conf"
# Capture system writes in a private directory; read existing settings only.
TEST_ROOT=$2/staged
font_install() {
    mkdir -p "$TEST_ROOT${2%/*}"
    cp "$1" "$TEST_ROOT$2"
}
font_read() {
    if [[ -f $TEST_ROOT$1 ]]; then cat "$TEST_ROOT$1"
    elif [[ -f $1 ]]; then cat "$1"; fi
}
font_system "$3"
''', 'font-check', str(root), directory, source], env=env, check=True,
                   stdout=subprocess.DEVNULL)
    staged = temporary / 'staged'
    script = (staged / 'usr/share/plymouth/themes/hexagon_hud_monocraft/hexagon_hud.script').read_text()
    assert script.count(', 1, 1, 1, 1, "Monocraft Nerd Font 12")') == 5
    psf = (staged / 'usr/share/kbd/consolefonts/monocraft.psf').read_bytes()
    assert psf == (root / 'assets/fonts/monocraft.psf').read_bytes()
    magic, version, header, flags, count, size, height, width = struct.unpack('<8I', psf[:32])
    assert magic == 0x864ab572 and flags == 1 and count == 256
    assert size == ((width + 7) // 8) * height
    assert psf[header + count * size:].count(b'\xff') == count
    assert any(psf[header + 65 * size:header + 66 * size])
    assert not any(psf[header + 32 * size:header + 33 * size])  # Space is blank.
    assert 'FONT=monocraft' in (staged / 'etc/vconsole.conf').read_text()
    assert 'Theme=hexagon_hud_monocraft' in (staged / 'etc/plymouth/plymouthd.conf').read_text()
    assert 'DeviceScale=1' in (staged / 'etc/plymouth/plymouthd.conf').read_text()
    assert 'Monocraft-nerd-fonts-patched.ttc' in (staged / 'etc/dracut.conf.d/30-monocraft.conf').read_text()
print(f'PASS: Bash INI preservation/idempotence/backups, font matching, emoji, Plymouth, {width}x{height} PSF and boot configuration')

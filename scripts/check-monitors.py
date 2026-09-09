#!/usr/bin/env python3
"""Exercise the Bash display controller without touching the desktop."""
from pathlib import Path
import unittest
import tempfile
import subprocess
import os
import json

ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / '.config/hypr/monitors.sh'


def call(function, *args, env=None):
    return subprocess.check_output(['bash', '-e', '-o', 'pipefail', '-c',
        'source "$1"; shift; "$@"', 'monitor-check', str(CONTROLLER), function, *args],
        text=True, env=env).strip()


class LayoutTests(unittest.TestCase):
    def test_geometry(self):
        internal = dict(width=2560, height=1600, scale=1)
        external = dict(width=3840, height=2160, scale=1.5)
        expected = {'right': [0, 0, 2560, 0], 'left': [2560, 0, 0, 0],
                    'top': [0, 1440, 0, 0], 'bottom': [0, 0, 0, 1600],
                    'duplicate': [0, 0, 0, 0]}
        for layout, positions in expected.items():
            self.assertEqual(json.loads(call('monitor_positions', layout, json.dumps(internal), json.dumps(external))), positions)
        external['transform'] = 1
        self.assertEqual(json.loads(call('monitor_positions', 'left', json.dumps(internal), json.dumps(external))), [1440, 0, 0, 0])
        external.update(width=2001, height=2005, scale=2, transform=0)
        self.assertEqual(json.loads(call('monitor_positions', 'left', json.dumps(internal), json.dumps(external))), [1000, 0, 0, 0])

    def test_identity(self):
        profiles = json.loads((ROOT / '.config/hypr/monitors.json').read_text())['profiles']
        self.assertEqual(profiles['Microstep MSI MAG272QR CA8A190020273']['layout'], 'right')
        self.assertNotIn('Another display', profiles)

    def test_hotplug_profiles(self):
        internal = dict(name='eDP-1', description='Panel', width=2560, height=1600, scale=1)
        external = dict(name='DP-7', description='Microstep MSI MAG272QR CA8A190020273', width=2560, height=1440, scale=1)
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            env = dict(os.environ, XDG_RUNTIME_DIR=directory, HYPRLAND_INSTANCE_SIGNATURE='test',
                       XDG_CONFIG_HOME=directory, MONITOR_TEST=directory)
            def run(*args, choice='2'):
                (folder / 'live.json').write_text(json.dumps([internal, external]))
                (folder / 'choice').write_text(choice)
                (folder / 'applied').write_text('')
                (folder / 'chosen').write_text('')
                subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', r'''
source "$1"; shift
monitor_query() { cat "$MONITOR_TEST/live.json"; }
monitor_choose() {
    printf '%s\n' "$1" >> "$MONITOR_TEST/chosen"
    [[ $(cat "$MONITOR_TEST/choice") != cancel ]] || return 1
    cat "$MONITOR_TEST/choice"
}
monitor_apply() { printf '%s %s\n' "$3" "$4" >> "$MONITOR_TEST/applied"; }
monitor_main "$@"
''', 'monitor-check', str(CONTROLLER), *args], env=env, check=True)
                return (folder / 'applied').read_text().strip(), (folder / 'chosen').read_text().strip()
            self.assertEqual(run('--auto'), ('right true', ''))
            self.assertEqual(run('--auto'), ('', ''))
            self.assertEqual(run('--auto', '--reload'), ('right false', ''))
            external['description'] = 'New monitor'
            self.assertEqual(run('--auto'), ('top true', 'External display position'))
            saved = folder / 'dots-monitors/profiles.json'
            self.assertEqual(json.loads(saved.read_text())['New monitor']['layout'], 'top')
            self.assertEqual(run('--auto', '--reload'), ('top false', ''))
            external['description'] = 'Cancelled monitor'
            self.assertEqual(run('--auto', choice='cancel')[0], '')
            self.assertNotIn('Cancelled monitor', json.loads(saved.read_text()))
            self.assertEqual(run(choice='1')[0], 'left true')

    def test_lua_encoding(self):
        self.assertEqual(call('monitor_lua_string', '";é'), '"\\034\\059\\195\\169"')
        self.assertEqual(call('monitor_lua_string', 'a\nb\\c'), '"\\097\\010\\098\\092\\099"')


if __name__ == '__main__':
    unittest.main()

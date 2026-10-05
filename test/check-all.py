#!/usr/bin/env python3
"""One entry point for dots source, behavior, installation and desktop checks.

Python 3.11+. Run from dots; existing suites are loaded from the neighboring
dots-maintenance/scripts directory. Also works inside a combined snapshot.
No third-party Python packages are needed.

  python3 -B test/check-all.py --list
  python3 -B test/check-all.py --only 'source/*' 'fast/*'
  python3 -B test/check-all.py                  # unavailable tests are SKIP
  python3 -B test/check-all.py --live --online --container

--live sends desktop input sequentially. --online allows public requests and
native theme-tool downloads. --container permits the disposable install test.
--clock-delivery temporarily installs/restores the clock helper; --audio changes
and restores playback volume. These two also require --live. Browser imports
need --extensions VIMIUM.xpi BONJOURR.xpi. No disk installer, reboot, real lock,
authentication attempt, radio change, deployment or personal browser import runs.

Exit 0: selected automated checks passed in full; 1: failure; 77: incomplete.
An all-checks run also records physical/VM acceptance gaps, so it cannot certify
an entire laptop from fixtures. Existing check failures are never suppressed.
"""
import argparse
import ast
import configparser
from collections import Counter
import fnmatch
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import runpy
import shlex
import shutil
import signal
import stat
import struct
import subprocess
import sys
import tempfile
import time
import tomllib
import traceback
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

SCRIPT = Path(__file__).resolve()
ROOT = SCRIPT.parents[1]
TOOLS = ROOT / 'scripts' if (ROOT / '.maintenance-source.json').exists() else ROOT.parent / 'dots-maintenance/scripts'
PYTHON = sys.executable


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def run(command, **kwargs):
    try:
        return subprocess.run(command, check=True, text=True, capture_output=True,
                              timeout=kwargs.pop('timeout', 60), **kwargs).stdout
    except subprocess.CalledProcessError as error:
        print((error.stdout or '') + (error.stderr or ''), file=sys.stderr)
        raise


def source_names():
    names = json.loads((ROOT / '.maintenance-source.json').read_text())
    require(isinstance(names, list) and names and len(names) == len(set(names)),
            'invalid source inventory')
    for name in names:
        require(isinstance(name, str) and not Path(name).is_absolute() and
                '..' not in Path(name).parts, f'unsafe inventory path: {name!r}')
    return sorted(names)


def fingerprint(directory, names):
    digest = hashlib.sha256()
    files = []
    for name in names:
        path = directory / name
        info = path.lstat()
        data = os.readlink(path).encode() if path.is_symlink() else path.read_bytes()
        row = dict(path=name, mode=stat.S_IMODE(info.st_mode),
                   kind='symlink' if path.is_symlink() else 'file',
                   sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))
        digest.update(json.dumps(row, sort_keys=True).encode() + b'\n')
        files.append(row)
    return digest.hexdigest(), files


def strict_json(text):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, f'duplicate JSON key: {key}')
            result[key] = value
        return result
    return json.loads(text, object_pairs_hook=pairs,
                      parse_constant=lambda value: require(False, f'invalid JSON constant: {value}'))


def jsonc(text):
    # Preserve quoted strings, including https:// URLs and escaped quotes.
    token = r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/'
    clean = re.sub(token, lambda m: m[0] if m[0].startswith('"') else ' ', text)
    clean = re.sub(r'("(?:\\.|[^"\\])*")|,(\s*[}\]])',
                   lambda m: m[1] if m[1] is not None else m[2], clean)
    return strict_json(clean)


def check_files():
    """Read every installation input; parse formats and detect dangling inputs."""
    failures, skips = [], set()
    for name in source_names():
        path = ROOT / name
        try:
            if path.is_symlink():
                require(path.resolve().is_relative_to(ROOT) and path.exists(),
                        'dangling or external source symlink')
            raw = path.read_bytes()
            if path.suffix in ('.qoi', '.ttc', '.psf', '.ogg'):
                require(len(raw) > 4, 'empty/truncated binary asset')
                magic = {'.qoi': b'qoif', '.ttc': b'ttcf', '.psf': b'\x72\xb5\x4a\x86', '.ogg': b'OggS'}
                require(raw.startswith(magic[path.suffix]), 'invalid binary signature')
                if path.suffix == '.qoi':
                    width, height, channels, colorspace = struct.unpack('>IIBB', raw[4:14])
                    require(width > 0 and height > 0 and channels in (3, 4) and colorspace in (0, 1), 'invalid QOI header')
                    require(raw.endswith(b'\0\0\0\0\0\0\0\1'), 'missing QOI end marker')
                continue
            text = raw.decode('utf-8')
            require('\0' not in text, 'NUL in text input')
            require(not re.search(r'^(?:<<<<<<< |=======\s*$|>>>>>>> )', text, re.M), 'unresolved merge conflict')
            if path.suffix in ('.json', '.jsonc'):
                (jsonc if path.suffix == '.jsonc' or '/Code - OSS/User/' in name else strict_json)(text)
            elif path.suffix == '.toml':
                tomllib.loads(text)
            elif path.suffix == '.svg' or text.lstrip().startswith('<?xml'):
                ET.fromstring(text)
            elif path.suffix == '.ini' or '/qt' in name and path.suffix == '.conf':
                parser = configparser.ConfigParser(interpolation=None, strict=False)
                parser.read_string(text)
            if path.suffix == '.py' or raw.startswith(b'#!/usr/bin/env python'):
                ast.parse(text, filename=name)
            elif path.suffix == '.sh' or path.name in ('.bashrc', '.bash_profile') or name.endswith('/uwsm/env'):
                run(['bash', '-n', str(path)])
            elif path.suffix == '.js':
                if shutil.which('node'):
                    run(['node', '--check', str(path)])
                else:
                    skips.add('JavaScript syntax needs node')
            elif path.suffix == '.lua':
                if shutil.which('luac'):
                    run(['luac', '-p', str(path)])
                else:
                    skips.add('Lua syntax needs luac')
            direct = (name == 'config/.config/hypr/scripts/autostart.sh' or
                      name == 'config/.config/waybar/focus-window.sh' or
                      name == 'config/.config/rofi/launcher.sh' or
                      name.startswith('config/.config/rofi/modi/') and
                      path.suffix == '.sh' and path.stem not in ('monitors', 'common', 'music', 'network', 'power', 'run'))
            if direct:
                require(path.stat().st_mode & 0o111, 'installed script is not executable')
            print(f'PASS file {name}')
        except (OSError, ValueError, AssertionError, SyntaxError, ET.ParseError,
                configparser.Error, subprocess.SubprocessError) as error:
            failures.append(name)
            print(f'FAIL file {name}: {error}')
    for message in sorted(skips):
        print(f'SKIP: {message}')
    require(not failures, f'{len(failures)} invalid installation inputs')


# Load the actual Lua configuration with recording implementations. Every bound
# callback is invoked, including the workspace loops and pointer timer callbacks;
# no compositor, command execution, user files or real input is involved.
LUA_BINDINGS = r'''
local calls, bindings, timers = {}, {}, {}
os.getenv = function(name) if name=='HYPRLAND_INSTANCE_SIGNATURE' then return 'test-session' end end
local function record(name, value) calls[#calls+1] = {name, value} end
local function dispatcher(name)
    return function(value) return function() record(name, value) end end
end
local methods = {'setup','browse','swap','resize','mouse','cycle_layout','toggle_sticky',
    'toggle_ontop','toggle_bar','minimize','restore','view','move'}
local desktop = {}
for _,name in ipairs(methods) do desktop[name] = function(value) record('dots.'..name, value) end end
package.preload['lua.desktop'] = function() return desktop end
hl = {
    monitor=function() end, env=function() end, config=function() end,
    curve=function() end, animation=function() end, on=function() end,
    window_rule=function() end, layer_rule=function() end,
    exec_cmd=function(command) record('exec',command) end,
    timer=function(fn) timers[#timers+1]=fn end,
    get_cursor_pos=function() return {x=100,y=200} end,
    bind=function(keys,fn,options) bindings[#bindings+1]={keys,fn,options or {}} end,
    dispatch=function(fn) fn() end,
    dsp={exec_cmd=dispatcher('exec'),focus=dispatcher('focus'),
         send_key_state=dispatcher('click'),cursor={move=dispatcher('cursor')},
         window=setmetatable({}, {__index=function(_,name) return dispatcher('window.'..name) end})}
}
dofile(arg[1])
local seen = {}
for _,binding in ipairs(bindings) do
    local keys,fn,options = table.unpack(binding)
    assert(not seen[keys], 'duplicate binding: '..keys); seen[keys]=true
    calls={}; fn()
    for _,timer in ipairs(timers) do timer() end; timers={}
    local labels={}
    for _,call in ipairs(calls) do
        local value=call[2]
        if type(value)=='table' then
            local parts={}; for k,v in pairs(value) do parts[#parts+1]=k..'='..tostring(v) end
            table.sort(parts); value=table.concat(parts,',')
        end
        labels[#labels+1]=call[1]..':'..tostring(value)
    end
    print(table.concat({keys,options.description or '',table.concat(labels,';'),
        tostring(options.locked or false),tostring(options.repeating or false),
        tostring(options.mouse or false)}, '\t'))
end
'''


def binding_rows():
    with tempfile.TemporaryDirectory(prefix='dots-bindings.') as temp:
        script = Path(temp) / 'bindings.lua'
        script.write_text(LUA_BINDINGS)
        output = run(['lua', str(script), str(ROOT / 'config/.config/hypr/hyprland.lua')])
    rows = [line.split('\t') for line in output.splitlines()]
    require(all(len(row) == 6 for row in rows), 'invalid binding capture')
    return {row[0]: row[1:] for row in rows}


def check_bindings():
    rows = binding_rows()
    expected = {
        'SHIFT + R': "exec:hyprctl reload && notify-send 'Hyprland configuration reloaded'",
        'SHIFT + Q': 'exec:uwsm stop', 'S': 'exec:~/.config/rofi/modi/keybinds.sh',
        'SHIFT + Tab': 'window.cycle_next:next=false', 'Tab': 'window.cycle_next:next=true',
        'comma': 'dots.browse:-1', 'period': 'dots.browse:1',
        'Return': 'exec:alacritty', 'B': 'exec:firefox', 'SHIFT + P': 'exec:kdeconnect-app',
        'E': 'exec:~/.config/rofi/launcher.sh menu', 'C': 'exec:code',
        'R': 'exec:~/.config/rofi/launcher.sh', 'P': 'exec:bash ~/.config/hypr/scripts/screenshot.sh',
        'L': 'exec:hyprlock', 'G': 'exec:bash ~/.config/visualizer/control.sh',
        'SHIFT + G': 'exec:bash ~/.config/garden/control.sh --toggle',
        'SHIFT + M': 'exec:bash ~/.config/miku/control.sh',
        'J': 'dots.swap:1', 'K': 'dots.swap:-1', 'SHIFT + J': 'dots.resize:+0.05',
        'SHIFT + K': 'dots.resize:-0.05', 'SHIFT + space': 'dots.cycle_layout:nil',
        'SHIFT + F': 'window.float:action=toggle', 'SHIFT + S': 'dots.toggle_sticky:nil',
        'SHIFT + T': 'dots.toggle_ontop:nil', 'T': 'dots.toggle_bar:nil',
        'F': 'window.fullscreen:action=toggle', 'Q': 'window.close:nil',
        'N': 'dots.minimize:nil', 'SHIFT + N': 'dots.restore:nil',
        'M': 'window.fullscreen:action=toggle,mode=maximized',
        'CTRL + P': 'exec:bash ~/.config/rofi/modi/monitors.sh',
        'semicolon': 'focus:monitor=+1', 'apostrophe': 'focus:monitor=-1',
        'SHIFT + semicolon': 'window.move:monitor=-1', 'SHIFT + apostrophe': 'window.move:monitor=+1',
        'mouse:272': 'dots.mouse:drag', 'mouse:273': 'dots.mouse:resize',
        'bracketleft': 'click:key=mouse:272,mods=,state=down;click:key=mouse:272,mods=,state=up',
        'bracketright': 'click:key=mouse:273,mods=,state=down;click:key=mouse:273,mods=,state=up',
    }
    for modifier, step in (('', 16), ('SHIFT + ', 3)):
        for key, dx, dy in (('left', -step, 0), ('right', step, 0), ('up', 0, -step), ('down', 0, step)):
            expected[modifier + key] = f'cursor:x={100+dx},y={200+dy}'
    for number in range(1, 10):
        expected[str(number)] = f'dots.view:{number}'
        expected[f'SHIFT + {number}'] = f'dots.move:{number}'
    expected = {'SUPER + ' + key: value for key, value in expected.items()}
    expected.update({
        'XF86PowerOff': 'exec:bash ~/.config/hypr/scripts/power.sh suspend',
        'XF86AudioRaiseVolume': 'exec:wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+',
        'XF86AudioLowerVolume': 'exec:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-',
        'XF86AudioMute': 'exec:wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle',
        'XF86AudioMicMute': 'exec:wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle',
        'XF86AudioPlay': 'exec:playerctl --player=spotify,%any play-pause',
        'XF86AudioNext': 'exec:playerctl --player=spotify,%any next',
        'XF86AudioPrev': 'exec:playerctl --player=spotify,%any previous',
        'XF86MonBrightnessUp': 'exec:brightnessctl set 5%+',
        'XF86MonBrightnessDown': 'exec:brightnessctl set 5%-',
        'Print': 'exec:bash ~/.config/hypr/scripts/screenshot.sh',
    })
    switches = {'switch:on:Lid Switch', 'switch:off:Lid Switch'}
    require(set(rows) == set(expected) | switches,
            f'bindings added/removed without expectations: {set(rows) ^ (set(expected) | switches)}')
    repeat = {f'SUPER + {prefix}{key}' for prefix in ('', 'SHIFT + ') for key in ('left', 'right', 'up', 'down')}
    repeat |= {'SUPER + SHIFT + J', 'SUPER + SHIFT + K', 'XF86AudioRaiseVolume', 'XF86AudioLowerVolume',
               'XF86MonBrightnessUp', 'XF86MonBrightnessDown'}
    for key, (description, action, locked, repeating, mouse) in rows.items():
        if key in switches:
            require(locked == 'true', f'{key} must work while locked')
            require(action == 'exec:bash ~/.config/hypr/monitors/monitors.sh --auto --reload; bash ~/.config/hypr/scripts/power.sh lid',
                    f'{key}: display/power callback changed')
            print(f'PASS {key}: {action}')
            continue
        require(description and action == expected[key], f'{key}: {action!r} != {expected[key]!r}')
        require((repeating == 'true') == (key in repeat), f'{key}: incorrect repeat flag')
        require((locked == 'true') == key.startswith('XF86'), f'{key}: incorrect lock flag')
        require((mouse == 'true') == (' + mouse:' in key), f'{key}: incorrect mouse flag')
        print(f'PASS {key}: {description} -> {action}')


def check_contracts():
    config = ROOT / 'config/.config'
    installer = (ROOT / 'install.sh').read_text()
    arrays = [re.search(r'^' + name + r'=\((.*?)^\)', installer, re.M | re.S)[1]
              for name in ('TASK_NAMES', 'TASK_CHECKS', 'TASK_INSTALLS')]
    labels, checks, installs = map(shlex.split, arrays)
    require(len(labels) == len(checks) == len(installs) == 30, 'installer task registry changed')
    for label, check, install in zip(labels, checks, installs):
        for function in (check, install):
            require(re.search(r'^' + function + r'\(\)', installer, re.M), f'{label}: missing {function}')
    require('install_system_update' not in installer, 'installer must only handle fresh setup')
    for path in config.glob('systemd/user/*'):
        content = path.read_text()
        for relative in re.findall(r'%h/(\.config/[\w./-]+)', content):
            require((ROOT / 'config' / relative).is_file(), f'{path.name}: missing {relative}')
        if path.suffix == '.timer':
            service = re.search(r'^Unit=(.+)$', content, re.M)
            target = service[1] if service else path.stem + '.service'
            require(path.with_name(target).exists(), f'{path.name}: missing timer service {target}')
    settings = strict_json((config / 'rofi/settings.json').read_text())
    require(set(settings['icons']) == {'run','files','ai','time','music','outputs','window','calc',
                                    'clipboard','autocorrector','wifi','bluetooth','power','power-mode'}, 'Rofi routes changed')
    for icon in settings['icons'].values():
        require((config / 'rofi/icon-gen/icons' / (icon + '.svg')).is_file(), f'missing icon {icon}')
    plugins = strict_json((config / 'BetterDiscord/data/stable/plugins.json').read_text())
    available = set()
    for path in (config / 'BetterDiscord/plugins').glob('*.plugin.js'):
        source = path.read_text()
        match = re.search(r'@name\s+([^\r\n]+)', source)
        require(match, f'{path.name}: missing plugin name')
        available.add(match[1].strip())
    require(all(not enabled or name in available for name, enabled in plugins.items()),
            f'enabled plugins missing: {[name for name, enabled in plugins.items() if enabled and name not in available]}')
    bars = jsonc((config / 'waybar/config.jsonc').read_text())
    require(len(bars) == 2, 'expected desktop bar and watermark')
    bar, watermark = bars
    require(bar['start_hidden'] and watermark['passthrough'] and not watermark['exclusive'], 'bar/watermark input policy')
    for n in range(1, 10):
        require(f'group/workspace{n}' in bar['modules-left'], f'workspace {n} missing')
        require(f'dots.view_at_cursor({n})' in bar[f'custom/workspace#{n}']['on-click'], f'workspace {n} click target')
    ai = strict_json((config / 'opencode/opencode.json').read_text())
    require(ai['model'] == 'llamacpp/' + settings['ai_model'], 'AI clients disagree on model alias')
    service = (config / 'systemd/user/llama-cpp.service').read_text()
    require('--alias ' + settings['ai_model'] in service and '--parallel 1' in service and
            '--host 127.0.0.1' in service, 'local model service contract')
    for command in ai['command'].values():
        require((config / 'opencode/agents' / (command['agent'] + '.md')).is_file(), 'command references missing agent')
    print('PASS task dispatch, installed unit targets, timers, icons, enabled plugins, workspace buttons and AI wiring')


def check_garden_control():
    with tempfile.TemporaryDirectory(prefix='dots-garden-control.') as temp:
        home = Path(temp)
        bins = home / 'bin'; bins.mkdir()
        for command, body in {'flock': 'exit 0', 'systemctl': 'exit "${TEST_SERVICE_FAILURE:-0}"'}.items():
            path = bins / command; path.write_text('#!/bin/sh\n' + body + '\n'); path.chmod(0o700)
        env = dict(os.environ, HOME=temp, XDG_STATE_HOME=temp + '/state', PATH=str(bins) + os.pathsep + os.environ['PATH'])
        command = ['bash', str(ROOT / 'config/.config/garden/control.sh'), '--toggle']
        marker = home / 'state/dots-garden/frozen'
        run(command, env=env); require(marker.exists(), 'freeze did not persist')
        run(command, env=env); require(not marker.exists(), 'resume did not clear freeze')
        for frozen in (False, True):
            if frozen: marker.touch()
            result = subprocess.run(command, env=dict(env, TEST_SERVICE_FAILURE='1'), capture_output=True, timeout=10)
            require(result.returncode != 0 and marker.exists() == frozen, 'failed service start changed freeze choice')
        result = subprocess.run(command[:-1] + ['--invalid'], env=env, capture_output=True, timeout=10)
        require(result.returncode == 2, 'unknown garden command accepted')
        require(stat.S_IMODE(marker.parent.stat().st_mode) == 0o700, 'garden state directory is not private')
    print('PASS freeze/resume persistence, failed-start rollback, private state and invalid commands; flock is mocked')


def check_ai():
    ai = runpy.run_path(str(ROOT / 'config/.config/rofi/modi/ai-request.py'))
    def rejects(function, *args):
        try: function(*args)
        except ValueError: return
        raise AssertionError('invalid input accepted: ' + repr(args)[:100])
    require(ai['read_text'](io.BytesIO(b'\xef\xbb\xbfhello\n')) == 'hello\n', 'UTF-8 BOM handling')
    require(len(ai['read_text'](io.BytesIO(b'x'*16000))) == 16000, 'attachment limit boundary')
    for raw in (b'', b' \n', b'x'*16001, b'\xff', b'%PDF-1.7', b'a\0b', b'a\x01b'):
        rejects(ai['read_text'], io.BytesIO(raw))
    with tempfile.TemporaryDirectory(prefix='dots-ai-fixture.') as temp:
        state = Path(temp) / 'state.json'
        ai['prepare'](state, 'Summarize', 'new', 'reference text', 'sample.txt')
        first = json.loads(state.read_text())
        require(first['status'] == 'running' and first['answer'] == '', 'new conversation state')
        require(first['messages'][0]['role'] == 'system' and
                first['messages'][1]['content'].endswith('Attached reference (sample.txt):\nreference text'), 'attachment wiring')
        before = state.read_bytes()
        for args in (('', 'new'), ('x'*8001, 'new'), ('next', 'followup'), ('x','invalid'), ('x','new','x'*24000,'large')):
            rejects(ai['prepare'], state, *args)
            require(state.read_bytes() == before, 'rejected input changed existing conversation')
        def event(delta):
            return ('data: '+json.dumps({'choices':[{'delta':delta}]})+'\n').encode()
        response = [b': heartbeat\n', event({'content':'Hello '}), b'data: {"usage":{}}\n',
                    event({'content':'world'}), b'data: [DONE]\n']
        published = []
        ai['stream_answer'](response, first, lambda value: published.append(dict(value)))
        require(published[-1]['status'] == 'done' and published[-1]['answer'] == 'Hello world', 'stream assembly/completion')
        ai['save'](state, first)
        ai['prepare'](state, 'Next question', 'followup')
        followup = json.loads(state.read_text())
        require(followup['messages'][-2:] == [{'role':'assistant','content':'Hello world'},
                                             {'role':'user','content':'Next question'}], 'follow-up history')
        for lines in ([], [b'data: [DONE]\n'], [event({'content':'unfinished'})],
                      [b'data: []\n'], [b'data: broken\n'], [b'data: {"error":"busy"}\n'],
                      [b'data: {"choices":"invalid"}\n'], [event({'content':3})],
                      [event({'reasoning_content':'hidden'})],
                      [event({'content':'<thi'}),event({'content':'nk>private'})]):
            rejects(ai['stream_answer'], lines, {}, lambda value: None)
        settings = strict_json((ROOT/'config/.config/rofi/settings.json').read_text())
        requests = []
        def urlopen(request, timeout):
            requests.append((request,timeout))
            return io.BytesIO(b''.join(response))
        with patch('urllib.request.urlopen', urlopen): ai['run'](state, settings)
        require(json.loads(state.read_text())['answer'] == 'Hello world', 'request response not saved')
        request, timeout = requests[0]
        body = json.loads(request.data)
        require(request.full_url == settings['ai_url'] and timeout == settings['ai_timeout'], 'request endpoint/deadline')
        require(body['model'] == settings['ai_model'] and body['stream'] and body['messages'] == followup['messages'] and
                body['chat_template_kwargs'] == {'enable_thinking':False} and body['reasoning_budget'] == 0,
                'model/request/context contract')
        with patch('urllib.request.urlopen', side_effect=OSError('synthetic failure')): ai['run'](state, settings)
        failed = json.loads(state.read_text())
        require(failed['status'] == 'error' and failed['answer'] == '' and 'synthetic failure' in failed['error'], 'failure leaked stale answer')
        require(stat.S_IMODE(state.stat().st_mode) == 0o600 and not list(Path(temp).glob('ai-state.*')), 'state permissions/temporary cleanup')
    print('PASS AI UTF-8 attachments, size limits, atomic state, follow-ups, streaming, malformed/no-thinking responses and request failure; HTTP is mocked')


def check_icons():
    with tempfile.TemporaryDirectory(prefix='dots-icons.') as temp:
        home=Path(temp); root=home/'rofi'
        shutil.copytree(ROOT/'config/.config/rofi',root)
        bins=home/'bin'; bins.mkdir()
        curl=bins/'curl'
        curl.write_text('''#!/bin/bash
[[ $1 == -fsSL && $2 == --max-time && $3 == 20 && $4 == https://raw.githubusercontent.com/lucide-icons/lucide/0.468.0/icons/*.svg && $5 == -o ]] || exit 99
printf '%s\\n' "$4" >> "$CALLS"
[[ $4 != */"${FAIL_ICON:-never}".svg ]] || exit 22
cp "$SVG_FIXTURE" "$6"
'''); curl.chmod(0o700)
        svg=home/'fixture.svg'; svg.write_text('<svg xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor"/>')
        env=dict(os.environ,PATH=str(bins)+os.pathsep+os.environ['PATH'],CALLS=str(home/'calls'),SVG_FIXTURE=str(svg))
        env.pop('ROFI_SETTINGS',None)
        command=['bash',str(root/'icon-gen/generate.sh')]
        icons=root/'icon-gen/icons'
        def contents(): return {p.name:p.read_bytes() for p in icons.iterdir()}
        before=contents()
        for names, extra in ((['zap','bot'],{'FAIL_ICON':'bot'}), (['../escape'],{}), (['--offline'],{})):
            result=subprocess.run(command+names,env=dict(env,**extra),capture_output=True,timeout=10)
            require(result.returncode != 0 and contents() == before, 'failed generation partially replaced icons')
        settings=strict_json((root/'settings.json').read_text())
        settings['icons']['run']='pencil'; settings['icon_color']='#123456'
        (root/'settings.json').write_text(json.dumps(settings))
        run(command,env=env)
        require((icons/'pencil.svg').exists(), 'personal icon mapping was omitted')
        for path in icons.iterdir():
            require(b'currentColor' not in path.read_bytes() and b'#123456' in path.read_bytes(), 'icon tint failed: '+path.name)
            ET.fromstring(path.read_bytes())
        before=contents(); svg.write_text('<html>error</html>')
        result=subprocess.run(command+['zap'],env=env,capture_output=True,timeout=10)
        require(result.returncode != 0 and contents()==before,'invalid download replaced icon')
        settings['icon_color']='red'; (root/'settings.json').write_text(json.dumps(settings))
        result=subprocess.run(command,env=env,capture_output=True,timeout=10)
        require(result.returncode != 0 and contents()==before,'invalid color accepted')
    print('PASS pinned icon URLs, personal mappings, tinting, validation and download-failure preservation; curl is mocked')


def check_current_power():
    # Reuse the existing private fixture; never call the host's logind or locker.
    Power=runpy.run_path(str(ROOT/'scripts/check-power.py'))['Power']
    case=Power(); case.setUp()
    try:
        for source, requested in (('battery','battery'),('ac','ac'),('battery','ac'),('ac','battery'),('unknown','battery')):
            case.log.unlink(missing_ok=True)
            result=case.run_policy('busctl() { echo \'s "yes"\'; }; power_idle '+requested,source=source)
            require(result.returncode==0,result.stderr)
            calls=case.calls()
            require(('systemctl suspend' in calls)==(source==requested),'idle source selection')
            if source==requested: require(calls.index('-j locked')<calls.index('systemctl suspend'),'suspend before lock')
        case.log.unlink(missing_ok=True)
        result=case.run_policy('busctl() { echo \'s "yes"\'; }; power_idle battery',locked='false')
        require(result.returncode!=0 and 'systemctl suspend' not in case.calls(),'failed lock permitted suspend')
        case.log.unlink(missing_ok=True)
        result=case.run_policy('mkdir -p "$POWER_STATE"; touch "$POWER_STATE/caffeine"; power_idle battery; power_lid')
        require(result.returncode==0 and not case.calls(),'caffeine failed to suppress automatic actions')
        config=(ROOT/'config/.config/hypr/hypridle.conf').read_text()
        listeners=re.findall(r'listener\s*\{([^}]+)\}',config)
        require(len(listeners)==2 and 'timeout = 300' in listeners[0] and 'idle battery' in listeners[0] and
                'timeout = 900' in listeners[1] and 'idle ac' in listeners[1], 'battery/AC inactivity deadlines')
    finally: case.doCleanups()
    print('PASS current 5/15-minute battery/AC policy, lock-before-suspend, lock failure and caffeine; desktop/system calls are mocked')


GARDEN_TEST = r'''
#define GARDEN_TEST
#include "renderer.c"
int main(int argc, char **argv) {
    g_assert_cmpint(argc, ==, 2);
    state_path = g_build_filename(argv[1], "state", NULL);
    backup_path = g_build_filename(argv[1], "state.bak", NULL);
    g_assert(load_tree());
    guint32 seed = tree.seed;
    tree.seconds = 12345; g_assert(save_tree());
    tree.seconds = 67890; g_assert(save_tree());
    g_assert(g_file_set_contents(state_path, "broken", -1, NULL));
    g_assert(load_tree()); g_assert(tree.seed == seed && tree.seconds == 12345);
    const char *bad[] = {"dots-garden 2 42 1 0", "dots-garden 1 42 0 0",
        "dots-garden 1 42 1 -1", "dots-garden 1 42 1 nan", "dots-garden 1 42 1 inf",
        "dots-garden 1 42 1 1e13", "dots-garden 1 42 1 0 trailing"};
    Tree parsed;
    for (guint i=0; i<G_N_ELEMENTS(bad); i++) {
        g_assert(g_file_set_contents(state_path,bad[i],-1,NULL));
        g_assert(!read_tree(state_path,&parsed));
    }
    g_assert(g_file_set_contents(backup_path,"broken",-1,NULL));
    g_assert(!load_tree()); /* Never silently replace a user's unreadable tree. */
    g_assert(elapsed(100,200)==0 && elapsed(2000000,1000000)==1);
    g_assert(event_phase(19,240,20,18)==-1 && event_phase(20,240,20,18)==0);
    g_assert(event_phase(38,240,20,18)==-1 && event_phase(260,240,20,18)==0);
    Cell a[ROWS][COLS], b[ROWS][COLS];
    Tree test={42,1,0}; garden(&test,a); garden(&test,b);
    g_assert(memcmp(a,b,sizeof a)==0);
    for (int age=0; age<10000; age+=50) {
        test.seconds=age*3600.0; garden(&test,b);
        for (int y=0;y<ROWS;y++) for (int x=0;x<COLS;x++) {
            g_assert(b[y][x].color<=4);
            g_assert(!b[y][x].glyph || (b[y][x].glyph>=32 && b[y][x].glyph<=126));
            if (y>=ROWS-3) g_assert(a[y][x].glyph==b[y][x].glyph);
        }
        Flight f=flight(age,FALSE), c=flight(age,TRUE);
        g_assert(isfinite(f.x) && isfinite(f.y) && f.dx!=0 && c.dx!=0);
    }
    g_assert(memcmp(a,b,sizeof a)!=0);
    g_free(state_path); g_free(backup_path);
    g_print("PASS garden deterministic growth, glyph bounds, fixed pot, age, events, backup recovery and corruption rejection\n");
    return 0;
}
'''


def check_renderers():
    flags = shlex.split(run(['pkg-config', '--cflags', '--libs', 'gtk+-3.0', 'gtk-layer-shell-0']))
    with tempfile.TemporaryDirectory(prefix='dots-renderers.') as temp:
        directory = Path(temp)
        for name in ('garden', 'visualizer'):
            source = ROOT / f'config/.config/{name}/renderer.c'
            binary = directory / name
            run(['clang', '-O2', '-Wall', '-Wextra', '-Werror', str(source), '-o', str(binary), *flags, '-lm'])
            if name == 'visualizer':
                print(run([str(binary), '--self-test']))
            else:
                harness = directory / 'garden-test.c'; harness.write_text(GARDEN_TEST)
                run(['clang', '-O1', '-g', '-fsanitize=address,undefined', '-I', str(source.parent),
                     str(harness), '-o', str(directory / 'garden-test'), *flags, '-lm'])
                print(run([str(directory / 'garden-test'), temp]))
                png = directory / 'garden.png'
                env = dict(os.environ, XDG_STATE_HOME=temp)
                run([str(binary), '--preview', '450', str(png)], env=env)
                raw = png.read_bytes()
                require(raw[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', raw[16:24]) == (1920,1080), 'invalid garden preview')
    print('PASS both renderers compile with warnings as errors; garden native state/geometry tested under sanitizers')


def check_installed_files():
    home = Path.home()
    data = Path(os.environ.get('XDG_DATA_HOME', home / '.local/share'))
    failures, mutable = [], []
    imports = {'config/bonjourr.json', 'config/vimium-options.json', 'config/nemo_config'}
    systems = {'config/system/pam.d/dots-hyprlock': '/etc/pam.d/dots-hyprlock',
               'config/system/logind/60-dots-power.conf': '/etc/systemd/logind.conf.d/60-dots-power.conf',
               'config/system/sleep/60-dots-power.conf': '/etc/systemd/sleep.conf.d/60-dots-power.conf',
               'config/system/pacman-hooks/90-dracut-install.hook': '/etc/pacman.d/hooks/90-dracut-install.hook'}
    for name in source_names():
        if name in systems:
            target = Path(systems[name])
        elif name.startswith('config/system/') or name in imports:
            continue
        elif name.startswith('config/'):
            target = home / name.removeprefix('config/')
        elif name.startswith('assets/sounds/'):
            target = data / 'dots-sounds' / Path(name).name
        elif name.startswith('assets/miku/'):
            target = data / 'dots-miku/prototypes/Miku' / name.removeprefix('assets/miku/')
        elif name.startswith('assets/fonts/'):
            target = (home / '.local/share/fonts' / Path(name).name if name.endswith('.ttc')
                      else Path('/usr/share/kbd/consolefonts/monocraft.psf'))
        else:
            continue
        try:
            require(target.is_file(), 'missing installed file')
            source = ROOT / name
            if source.read_bytes() != target.read_bytes():
                # These applications rewrite preferences or update vendor plugins.
                if (name.endswith('/rofi/settings.json') or '/BetterDiscord/' in name or
                        '/keepassxc/' in name):
                    mutable.append(name)
                    print(f'SKIP: {name}: installed personal/application state differs; not overwritten')
                    continue
                raise AssertionError('installed bytes differ from candidate')
            require(not (source.stat().st_mode & 0o111) or target.stat().st_mode & 0o111, 'executable mode missing')
            print(f'PASS installed {name}')
        except (OSError, AssertionError) as error:
            failures.append(name); print(f'FAIL installed {name}: {error}')
    print('SKIP: browser/Nemo imports and account preferences require application-level checks; file equality does not establish imports')
    require(not failures, f'{len(failures)} missing/differing installed files')


def session_environment(unlocked=False):
    env = dict(os.environ, XDG_RUNTIME_DIR=f'/run/user/{os.getuid()}')
    instances = json.loads(run(['hyprctl', '-j', 'instances'], env=env))
    require(len(instances) == 1, 'requires exactly one Hyprland session')
    env.update(HYPRLAND_INSTANCE_SIGNATURE=instances[0]['instance'], WAYLAND_DISPLAY=instances[0]['wl_socket'])
    if unlocked:
        require(not json.loads(run(['hyprctl', '-j', 'locked'], env=env))['locked'], 'unlock the desktop before input checks')
    return env


def check_session():
    env = session_environment()
    require(not run(['hyprctl', 'configerrors'], env=env).strip(), 'Hyprland has configuration errors')
    processes = []
    for directory in Path('/proc').iterdir():
        if not directory.name.isdigit(): continue
        try:
            if directory.stat().st_uid == os.getuid():
                processes.append((int(directory.name), directory.joinpath('cmdline').read_bytes().split(b'\0')))
        except (OSError, ProcessLookupError):
            continue
    for executable in ('waybar', 'mako', 'pcloud', 'discord', 'spotify', 'alacritty', 'nemo', 'code', 'firefox'):
        aliases = {'pcloud': {'pcloud', 'pcloud.bin'}, 'code': {'code', 'code-oss'}, 'firefox': {'firefox', 'firefox-bin'}}.get(executable, {executable})
        found = [pid for pid, args in processes if args and Path(os.fsdecode(args[0])).name.lower() in aliases]
        require(found, f'autostart application is not running: {executable} (may have been closed after login)')
        print(f'PASS running {executable}')
    for kind in ('text', 'image'):
        expected = [b'wl-paste', b'--type', kind.encode(), b'--watch', b'cliphist', b'store']
        count = sum(len(args) >= 6 and Path(os.fsdecode(args[0])).name == 'wl-paste' and args[1:6] == expected[1:]
                    for _, args in processes)
        require(count == 1, f'{kind} clipboard watcher count {count}, expected 1')
    for unit in ('dots-garden.service','dots-battery.timer','hypridle.service','dots-power.service',
                 'hyprpolkitagent.service','hyprsunset.service','llama-cpp.service'):
        active = run(['systemctl','--user','show',unit,'-p','ActiveState','--value'], env=env).strip()
        require(active == 'active', f'{unit}: {active}')
        print(f'PASS active {unit}')
    for unit in ('dots-miku.service', 'dots-visualizer.service'):
        state = run(['systemctl','--user','show',unit,'-p','ActiveState','--value'], env=env).strip()
        require(state in ('active','inactive'), f'{unit}: {state}')
        print(f'PASS optional overlay {unit}: {state}')
    loaded = json.loads(run(['hyprctl','-j','binds'], env=env))
    expected = binding_rows()
    for combination, (description, _, locked, repeating, mouse) in expected.items():
        if combination.startswith('switch:'):
            candidates = [row for row in loaded if row.get('key') == combination]
        else:
            parts = combination.split(' + ')
            mask = sum({'SUPER':64,'SHIFT':1,'CTRL':4}[part] for part in parts[:-1])
            candidates = [row for row in loaded if row.get('modmask') == mask and row.get('key','').lower() == parts[-1].lower()]
        require(len(candidates) == 1, f'{combination}: expected exactly one loaded binding, found {len(candidates)}')
        row = candidates[0]
        require(row.get('description','') == description, f'{combination}: loaded description differs')
        for field, value in (('locked',locked),('repeat',repeating),('mouse',mouse)):
            require(bool(row.get(field,False)) == (value == 'true'), f'{combination}: loaded {field} flag differs')
    print('PASS loaded keyboard/mouse/lid bindings and required session processes; actual actions have separate tests')


def check_packages():
    installer = (ROOT / 'install.sh').read_text()
    for name in ('REPO_PACKAGES','AUR_PACKAGES'):
        match = re.search(r'readonly -a ' + name + r'=\((.*?)\)', installer, re.S)
        require(match, f'missing {name}')
        packages = shlex.split(match[1], comments=True)
        result = subprocess.run(['pacman','-Qq',*packages], text=True, capture_output=True, timeout=30)
        require(result.returncode == 0, f'{name}: {result.stderr.strip()}')
        print(f'PASS {len(packages)} installed {name}')
    for unit in ('bluetooth.service','docker.service','power-profiles-daemon.service','NetworkManager.service'):
        require(run(['systemctl','is-enabled',unit]).strip() == 'enabled', f'{unit} not enabled')
    require(run(['systemctl','show','suspend.target','-p','LoadState','--value']).strip() == 'loaded', 'suspend unavailable')
    for unit in ('hibernate.target','hybrid-sleep.target','suspend-then-hibernate.target'):
        require(run(['systemctl','show',unit,'-p','LoadState','--value']).strip() == 'masked', f'{unit} not masked')
    print('PASS packages, system service enablement and suspend-only policy')


WORKERS = {'files': check_files, 'contracts': check_contracts, 'bindings': check_bindings,
           'garden-control': check_garden_control, 'renderers': check_renderers,
           'ai': check_ai, 'icons': check_icons, 'current-power': check_current_power,
           'installed-files': check_installed_files, 'session': check_session, 'packages': check_packages}


def registry(args):
    legacy = runpy.run_path(str(TOOLS / 'check.py'))
    cases = []
    def add(name, command, required='', effect='', gates=()):
        cases.append(dict(name=name, command=command, required=required.split(), effect=effect, gates=list(gates)))
    for name, required in (('files','bash'),('contracts',''),('bindings','lua'),('garden-control','bash'),
                           ('ai',''),('icons','bash jq'),('current-power','bash jq')):
        add('source/'+name, [PYTHON,'-B',str(SCRIPT),'--worker',name], required, 'source validation / isolated fixtures')
    add('source/desktop', ['lua','scripts/check-desktop.lua'], 'lua', 'compositor policy model')
    add('source/vscode-backup', [PYTHON, '-B', 'test/check-vscode-backup.py'], '',
        'private config export/install fixtures; no personal editor data')
    for group, key in (('fast','FAST'),('arch','ARCH'),('live','LIVE')):
        for name, command, required, effect in legacy[key]:
            if group == 'arch' and name == 'desktop': continue
            gates = [] if group == 'fast' else ['arch']
            if group == 'live': gates += ['live']
            if group == 'arch' and name == 'app-themes': gates += ['online']
            if name == 'fresh-install': gates += ['container','online']
            add(group+'/'+name, command, required, effect, gates)
    for name, worker, required in (('renderers','renderers','clang pkg-config'),
                                   ('installed-files','installed-files',''),
                                   ('packages','packages','pacman systemctl'),
                                   ('session','session','hyprctl systemctl lua')):
        group = 'arch' if name == 'renderers' else 'installed'
        add(group+'/'+name,[PYTHON,'-B',str(SCRIPT),'--worker',worker],required,
            'native renderer fixtures' if name == 'renderers' else 'read-only installed state (full setup expected)', ['arch'])
    extra = [
        ('rofi',['bash','scripts/check-rofi-live.sh'],'hyprctl rofi jq grim','menu shortcuts, typing and Files cancellation'),
        ('network-menus',['bash','scripts/check-rofi-live.sh','--network'],'hyprctl rofi jq nmcli bluetoothctl','reads device names; cancels menus without radio changes'),
        ('desktop',[PYTHON,'-B','scripts/check-desktop-live.py'],'hyprctl alacritty','nine owned terminals, layouts, minimize/restore/sticky; restores desktop'),
        ('workspace-motion',[PYTHON,'-B','scripts/check-workspace-motion-live.py'],'hyprctl','workspace transitions; restores workspaces/focus'),
        ('media-gui',[PYTHON,'-B','scripts/check-media-live.py','--gui'],'Hyprland rofi pipewire pipewire-pulse wireplumber pactl playerctl vlc','private audio and nested compositor; GUI selection'),
        ('ai',[PYTHON,'-B','scripts/check-ai-live.py'],'Hyprland rofi systemctl curl','synthetic requests to idle local model; restores AI state'),
        ('opencode-smoke',[PYTHON,'-B','scripts/check-opencode.py','--smoke'],'opencode','synthetic read-tool call after AI cleanup; temporary HOME'),
        ('screenshot',[PYTHON,'-B','scripts/check-screenshot-live.py'],'hyprctl grim slurp swappy','captures small actual desktop region; brief sound; closes owned editor'),
        ('monitors',[PYTHON,'-B','scripts/check-monitors-live.py'],'hyprctl rofi jq','changes/restores two-monitor geometry and focus'),
        ('miku-drag',[PYTHON,'-B','scripts/check-miku-drag-live.py'],'hyprctl shimejictl clang pkg-config','private renderer; pointer input across two scale-1 displays; restores input/focus'),
    ]
    for name, command, required, effect in extra:
        add('live/'+name, command, required, effect, ['arch','live'])
    add('live/clock-delivery',['bash','scripts/check-clock-live.sh','--snapshot'],'hyprctl systemctl jq',
        'empty clocks required; temporarily replaces/restores helper; notifications and sound', ['arch','live','clock_delivery'])
    add('live/volume',['bash','scripts/check-visualizer-volume-live.sh'],'wpctl playerctl cava jq',
        'Spotify must be playing; lowers/restores real output/player volume', ['arch','live','audio'])
    add('online/mtg',[PYTHON,'-B','scripts/check-mtg-live.py'],'','public API calls; temporary HOME; no deck publication',['online'])
    add('online/archidekt',['node','scripts/check-archidekt-live.mjs',str(args.archidekt or '')], 'node firefox',
        'opens provided public sandbox artifact in disposable browser; no save', ['online','archidekt'])
    add('browser/extensions',['node','scripts/check-browser.mjs','--live',*(str(p) for p in (args.extensions or []))],
        'node firefox','reviewed XPI imports and keyboard behavior in disposable Firefox',['extensions'])
    # Compatibility entry points delegate to these exact tests; do not run twice.
    aliases = {'check-ai-live.sh':'check-ai-live.py','check-miku-walls-live.py':'check-miku-drag-live.py',
               'check-visualizer-live.sh':'check-overlays-live.py'}
    registered = {Path(word).name for case in cases for word in case['command']}
    for path in sorted(TOOLS.glob('check-*')):
        if path.name not in registered | set(aliases) | {'check-all.py','check-power-migration.py'}:
            raise ValueError(f'unregistered check: {path.name}; add its command/prerequisites')
    # Migration is a maintenance workflow, but include its isolated fixtures too.
    add('fast/power-migration',[PYTHON,'-B','scripts/check-power-migration.py','-v'],'bash jq','isolated maintenance recovery fixtures')
    return cases


def outcome(code, output):
    skips = [line for line in output.splitlines() if re.search(
        r'^\s*SKIP\b|\.\.\. skipped |^OK \(.*skipped=\d+|^\s*[Ss]kipped:', line)]
    return ('FAIL' if code not in (0,77) else 'SKIP' if code == 77 or skips else 'PASS'), skips


def execute(command, log, timeout, env):
    """Stream to disk; bounded wait; let fixtures restore state before killing."""
    with log.open('w') as output:
        child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output,
                                 stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = child.wait(timeout=timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            interrupted = isinstance(error, KeyboardInterrupt)
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGINT)
            try: child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL); child.wait()
            output.write('\nFAIL: interrupted/timed out; inspect cleanup before rerunning\n')
            if interrupted: raise
            code = 1
    return code


def self_test():
    class RunnerTests(unittest.TestCase):
        def test_status(self):
            for code, output, expected in [(0,'PASS: fine','PASS'),(0,'SKIP: native','SKIP'),
                    (0,"test_x ... skipped 'missing'",'SKIP'),(0,'OK (skipped=2)','SKIP'),
                    (77,'','SKIP'),(1,'SKIP: optional','FAIL'),(-9,'','FAIL')]:
                self.assertEqual(outcome(code,output)[0],expected)
        def test_json(self):
            self.assertEqual(jsonc('{"url":"https://x//y", /* comment */ "a":[1,],}'), {'url':'https://x//y','a':[1]})
            for text in ('{"a":1,"a":2}','{"x":NaN}','{"x":'):
                with self.assertRaises((ValueError,AssertionError)): strict_json(text)
        def test_receipt_detects_modes_and_docs(self):
            with tempfile.TemporaryDirectory() as temp:
                directory=Path(temp); path=directory/'README.md'; path.write_text('one')
                first=fingerprint(directory,['README.md'])[0]
                path.write_text('two'); second=fingerprint(directory,['README.md'])[0]
                path.chmod(0o700); third=fingerprint(directory,['README.md'])[0]
                self.assertEqual(len({first,second,third}),3)
        def test_failed_and_timed_out_child(self):
            with tempfile.TemporaryDirectory() as temp:
                log=Path(temp)/'log'
                self.assertEqual(execute([PYTHON,'-c','raise SystemExit(3)'],log,5,os.environ.copy()),3)
                self.assertEqual(execute([PYTHON,'-c','import time; time.sleep(30)'],log,.1,os.environ.copy()),1)
                self.assertIn('timed out',log.read_text())
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(RunnerTests))
    return 0 if result.wasSuccessful() else 1


def main():
    global ROOT, TOOLS, SCRIPT
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--repo',type=Path,help='installation checkout (default: this repository)')
    parser.add_argument('--only',nargs='+',help='exact names or glob patterns from --list')
    parser.add_argument('--list',action='store_true',help='list all checks, gates and effects without running')
    parser.add_argument('--live',action='store_true',help='enable sequential graphical/input checks; stop typing during them')
    parser.add_argument('--online',action='store_true',help='enable public requests and native theme-tool downloads')
    parser.add_argument('--container',action='store_true',help='enable disposable Docker installation')
    parser.add_argument('--clock-delivery',action='store_true',help='allow clock helper backup/temporary replacement/restoration')
    parser.add_argument('--audio',action='store_true',help='allow playback volume reduction/restoration')
    parser.add_argument('--extensions',nargs=2,type=Path,metavar=('VIMIUM_XPI','BONJOURR_XPI'))
    parser.add_argument('--archidekt',type=Path,help='public archidekt.json produced by online/mtg for browser import')
    parser.add_argument('--timeout',type=float,default=1800,help='maximum seconds per check (default 1800)')
    parser.add_argument('--self-test',action='store_true',help='exercise runner failure/skip/timeout handling')
    parser.add_argument('--worker',choices=WORKERS,help=argparse.SUPPRESS)
    args=parser.parse_args()
    if sys.flags.optimize: parser.error('remove -O / PYTHONOPTIMIZE: checks require assertions')
    if not math.isfinite(args.timeout) or args.timeout <= 0: parser.error('--timeout must be finite and positive')
    if args.worker:
        try: WORKERS[args.worker](); return 0
        except Exception: traceback.print_exc(); return 1
    if args.self_test: return self_test()
    for name in ('archidekt',):
        if getattr(args,name): setattr(args,name,getattr(args,name).expanduser().resolve())
    if args.extensions: args.extensions=[path.expanduser().resolve() for path in args.extensions]
    if not all((TOOLS/name).is_file() for name in ('check.py','laptop-dev.py')):
        parser.error(f'existing test suite is required at {TOOLS}')
    cases=registry(args)
    if args.only:
        for pattern in args.only:
            if not any(fnmatch.fnmatchcase(case['name'],pattern) for case in cases): parser.error('no checks match '+pattern)
        cases=[case for case in cases if any(fnmatch.fnmatchcase(case['name'],p) for p in args.only)]
    if args.list:
        for case in cases:
            print(f"{case['name']} [{', '.join(case['gates']) or 'offline'}]\n  {shlex.join(case['command'])}\n  Tools: {', '.join(case['required']) or 'Python 3.11+'}\n  {case['effect']}")
        return 0
    if not (ROOT/'.maintenance-source.json').exists():
        source=(args.repo or ROOT).expanduser().resolve()
        if (source/'scripts/check-all.py').exists():
            parser.error('snapshot runner would replace source scripts/check-all.py')
        destination=Path(tempfile.mkdtemp(prefix='dots-all-source.'))
        helper=runpy.run_path(str(TOOLS/'laptop-dev.py'))
        helper['prepare_snapshot'](source,destination,tools_dir=TOOLS)
        shutil.copy2(SCRIPT,destination/'scripts/check-all.py')
        ROOT=destination
        TOOLS=ROOT/'scripts'
        SCRIPT=TOOLS/'check-all.py'
        cases=registry(args)
        if args.only: cases=[c for c in cases if any(fnmatch.fnmatchcase(c['name'],p) for p in args.only)]
        print(f'Test snapshot: {ROOT}',flush=True)
    output=Path(tempfile.mkdtemp(prefix='dots-all-results.'))
    names=source_names()
    before, inventory=fingerprint(ROOT,names)
    tools_before,_=fingerprint(ROOT,sorted(str(p.relative_to(ROOT)) for p in (ROOT/'scripts').iterdir() if p.is_file()))
    print(f'Logs and receipt: {output}\nSource files: {len(names)}',flush=True)
    results=[]
    env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',PYTHONUNBUFFERED='1')
    for key in ('BASH_ENV','ENV','PYTHONOPTIMIZE','PYTHONPATH'): env.pop(key,None)
    arch=Path('/etc/arch-release').exists()
    interrupted=False
    for case in cases:
        name=case['name']; log=output/(name.replace('/','--')+'.log')
        reason=''; code=77; started=time.monotonic()
        for gate in case['gates']:
            if gate=='arch' and not arch: reason='requires Arch Linux'; break
            if gate!='arch' and not getattr(args,gate): reason='requires --'+gate.replace('_','-'); break
        missing=[exe for exe in case['required'] if not shutil.which(exe)]
        if not reason and missing: reason='missing executables: '+', '.join(missing)
        print(f"RUN {name}: {case['effect']}",flush=True)
        try:
            if not reason and 'live' in case['gates']:
                try: env.update(session_environment(unlocked=True))
                except (AssertionError,OSError,ValueError,subprocess.SubprocessError) as error:
                    reason='desktop prerequisite: '+str(error)
            if reason: log.write_text('SKIP: '+reason+'\n')
            else: code=execute(case['command'],log,args.timeout,env)
        except KeyboardInterrupt:
            interrupted=True; code=1
        except (OSError,subprocess.SubprocessError) as error:
            code=1; log.write_text(f'FAIL: {error}\n')
        content=log.read_text(errors='replace')
        status,skips=outcome(code,content)
        results.append(dict(**case,status=status,code=code,skips=skips,log=str(log),seconds=round(time.monotonic()-started,2)))
        print(f'{status} {name}',flush=True)
        if status=='FAIL':
            # A full file scan can push the actual error out of the tail.
            problems=[line for line in content.splitlines() if re.match(r'^(?:FAIL|ERROR)\b',line)]
            print('\n'.join(problems[:20])+'\n'+content[-2200:],flush=True)
        elif skips: print('\n'.join(skips),flush=True)
        # Write progress after each test so a killed runner still leaves evidence.
        (output/'results.json').write_text(json.dumps(dict(source_sha256=before,results=results,complete=False),indent=2)+'\n')
        if interrupted: break
    after,_=fingerprint(ROOT,names)
    tools_after,_=fingerprint(ROOT,sorted(str(p.relative_to(ROOT)) for p in (ROOT/'scripts').iterdir() if p.is_file()))
    if (before,tools_before)!=(after,tools_after):
        results.append(dict(name='source-unchanged',status='FAIL',skips=[],effect='candidate or test files changed during execution'))
    gaps=[
        'Full bootstrap/partition/LUKS/UEFI boot and package installation require a disposable booted VM.',
        'Physical lid/power keys, suspend/wake authentication, fingerprint reader, hotplug, gestures and battery drain require local acceptance.',
        'Account login/sync, personal browser imports, phone pairing, speaker audibility and third-party plugin UI behavior require application/hardware acceptance.',
    ]
    if not args.only:
        for number,gap in enumerate(gaps,1):
            results.append(dict(name=f'acceptance/{number}',status='SKIP',skips=[gap],effect=gap))
            print('SKIP '+gap)
    counts=Counter(row['status'] for row in results)
    receipt=dict(source_root=str(ROOT),source_sha256=before,source_after_sha256=after,
                 tests_sha256=tools_before,tests_after_sha256=tools_after,files=inventory,
                 results=results,counts=dict(counts),acceptance_gaps=gaps,complete=not interrupted,
                 scope=args.only or ['all'],platform=sys.platform)
    (output/'results.json').write_text(json.dumps(receipt,indent=2)+'\n')
    summary=[f'Source: {ROOT}',f'Source SHA256: {before}','',
             '| Check | Result | Log |','| --- | --- | --- |']
    summary += [f"| {r['name']} | {r['status']} | {r.get('log','manual acceptance')} |" for r in results]
    summary += ['','Acceptance still required:',*('- '+gap for gap in gaps)]
    (output/'report.md').write_text('\n'.join(summary)+'\n')
    print(' / '.join(f'{counts[status]} {status}' for status in ('PASS','FAIL','SKIP')))
    print(f'Receipt: {output}/results.json\nReport: {output}/report.md')
    return 1 if counts['FAIL'] else 77 if counts['SKIP'] else 0


if __name__=='__main__':
    sys.exit(main())

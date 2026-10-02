#!/usr/bin/env python3
"""Run: python3 tests/rofi-ai.py. No desktop, model, or network required."""
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1] / "config/.config/rofi"
spec = importlib.util.spec_from_file_location("ai_request", ROOT / "modi/ai-request.py")
ai = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ai)


def rejects(call):
    try:
        call()
    except ValueError:
        return
    raise AssertionError("Invalid input was accepted")


def event(content):
    return ('data: ' + json.dumps({"choices": [{"delta": {"content": content}}]}) + '\n').encode()


with tempfile.TemporaryDirectory() as temporary:
    work = Path(temporary)
    state_file = work / "ai.json"
    ai.prepare(state_file, "Explain this", "new", "some source code", "example.py")
    state = json.loads(state_file.read_text())
    updates = []

    def publish(value):
        updates.append(json.loads(json.dumps(value)))

    def chunks():
        yield event("Hello")
        assert updates[-1]["status"] == "running" and updates[-1]["answer"] == "Hello"
        yield event(" world")
        yield b'data: [DONE]\n'

    ai.stream_answer(chunks(), state, publish)
    assert updates[-1]["status"] == "done" and updates[-1]["answer"] == "Hello world"
    ai.save(state_file, state)
    ai.prepare(state_file, "Why?", "followup")
    messages = json.loads(state_file.read_text())["messages"]
    assert [m["role"] for m in messages] == ["system", "user", "assistant", "user"]
    assert "some source code" in messages[1]["content"]
    assert messages[2]["content"] == "Hello world" and messages[3]["content"] == "Why?"
    rejects(lambda: ai.prepare(state_file, "Too soon", "followup"))
    before = state_file.read_bytes()
    rejects(lambda: ai.prepare(state_file, "x", "new", "x" * ai.CONTEXT_LIMIT))
    assert state_file.read_bytes() == before
    ai.prepare(state_file, "Fresh question", "new")
    assert len(json.loads(state_file.read_text())["messages"]) == 2
    for raw in (b"", b"\x00binary", b"\xff", b"%PDF-1.7", b"x" * (ai.TEXT_LIMIT + 1)):
        rejects(lambda: ai.read_text(io.BytesIO(raw)))
    assert ai.read_text(io.BytesIO("Здравей\ntext".encode())) == "Здравей\ntext"
    for stream in ([event("partial")], [b'data: [DONE]\n'], [b'data: broken\n'],
                   [event("<thi"), event("nk>secret")],
                   [b'data: {"choices":[{"delta":{"reasoning_content":"secret"}}]}\n']):
        rejects(lambda: ai.stream_answer(stream, {}, lambda _: None))

    # Exercise request construction and error publication without contacting a server.
    settings = {"ai_model": "test", "ai_url": "http://127.0.0.1:8080/test", "ai_timeout": 30}
    with patch.object(ai.urllib.request, "urlopen", return_value=io.BytesIO(event("Answer") + b'data: [DONE]\n')) as request:
        ai.run(state_file, settings)
        payload = json.loads(request.call_args.args[0].data)
        assert payload["messages"][-1]["content"] == "Fresh question" and payload["stream"]
    assert json.loads(state_file.read_text())["status"] == "done"
    with patch.object(ai.urllib.request, "urlopen", side_effect=OSError("offline")):
        ai.run(state_file, settings)
    assert "offline" in json.loads(state_file.read_text())["error"]

    # Run the real Bash menus and Files handoff with only platform commands stubbed.
    binaries = work / "bin"
    binaries.mkdir()
    scripts = {
        "flock": "exit 0\n",  # Single-process test only.
        "systemctl": '''case "$*" in
    *is-active*) [[ -f $XDG_RUNTIME_DIR/active ]];;
    *stop*) rm -f "$XDG_RUNTIME_DIR/active";;
    *) exit 1;;
esac
''',
        "systemd-run": '''python3 - <<'PY'
import json, os
from pathlib import Path
p = Path(os.environ['XDG_RUNTIME_DIR']) / 'dots-utils/ai.json'
s = json.loads(p.read_text())
with open(os.environ['TEST_REQUESTS'], 'a') as out:
    out.write(json.dumps(s) + '\\n')
s.update(status='done', answer='Test answer')
p.write_text(json.dumps(s))
PY
''',
        "alacritty": 'while [[ $1 != -e ]]; do shift; done; shift; exec "$@"\n',
        "fd": 'printf "%s\\0" "$TEST_FILE"\n',
        "fzf": 'cat >/dev/null; [[ ${TEST_CANCEL:-0} != 1 ]] || exit 130; printf "%s\\0" "$TEST_FILE"\n',
        "code": 'printf "%s\\0" "$@" > "$TEST_OPENED"\n',
        "wl-paste": 'printf "%s" "Clipboard sample"\n',
        "wl-copy": 'cat > "$TEST_COPIED"\n',
    }
    for name, script in scripts.items():
        executable = binaries / name
        executable.write_text("#!/bin/bash\n" + script)
        executable.chmod(0o755)
    attached = work / "spaces ' and\nnewline.txt"
    attached.write_text("Attachment contents")
    env = dict(os.environ, PATH=f"{binaries}:{os.environ['PATH']}",
               XDG_RUNTIME_DIR=str(work), XDG_STATE_HOME=str(work / "state"),
               XDG_CACHE_HOME=str(work / "cache"), TEST_FILE=str(attached),
               TEST_REQUESTS=str(work / "requests"), TEST_OPENED=str(work / "opened"),
               TEST_COPIED=str(work / "copied"), TEST_CHOICES=str(work / "choices"),
               TEST_ACTIONS=str(work / "actions"), TEST_ROOT=str(ROOT))
    setup = '''
set -uo pipefail
source "$TEST_ROOT/modi/common.sh"
source "$TEST_ROOT/modi/files.sh"
source "$TEST_ROOT/modi/ai.sh"
# macOS Bash 3 lacks fractional read timeouts; these tests supply all events upfront.
if ((BASH_VERSINFO[0] < 4)); then
    read() {
        local args=()
        while (($#)); do
            if [[ $1 == -t ]]; then shift 2; else args+=("$1"); shift; fi
        done
        builtin read "${args[@]}"
    }
fi
choose() {
    CHOICE=$(head -n 1 "$TEST_CHOICES")
    sed '1d' "$TEST_CHOICES" > "$TEST_CHOICES.next"
    mv "$TEST_CHOICES.next" "$TEST_CHOICES"
    [[ -n $CHOICE ]]
}
prompt() { ANSWER='User question'; }
info() { printf '%s\\n' "$*" >&2; exit 99; }
live_menu() {
    head -n 1 "$TEST_ACTIONS" > "$RUNTIME/ai-action"
    sed '1d' "$TEST_ACTIONS" > "$TEST_ACTIONS.next"
    mv "$TEST_ACTIONS.next" "$TEST_ACTIONS"
}
'''

    def shell(body, **overrides):
        return subprocess.run(["bash", "-c", setup + body], env=dict(env, **overrides),
                              capture_output=True, text=True, timeout=15)

    (work / "choices").write_text("5\n0\n0\n")
    (work / "actions").write_text("followup\nnew\nclose\n")
    result = shell("ai_menu")
    assert result.returncode == 0, result.stderr
    requests = [json.loads(line) for line in (work / "requests").read_text().splitlines()]
    assert "Attachment contents" in requests[0]["messages"][-1]["content"]
    assert len(requests[1]["messages"]) == 4
    assert len(requests[2]["messages"]) == 2
    assert "Attachment contents" not in requests[2]["messages"][-1]["content"]
    assert not (work / "opened").exists(), "Attaching must not open VS Code"

    for action in range(1, 5):
        (work / "choices").write_text(f"{action}\n0\n")
        (work / "actions").write_text("close\n")
        result = shell("ai_menu")
        assert result.returncode == 0, result.stderr
        last = json.loads((work / "requests").read_text().splitlines()[-1])
        assert "Clipboard sample" in last["messages"][-1]["content"]
        assert last["messages"][-1]["content"].startswith(("Explain", "Summarize", "Translate", "Rewrite")[action - 1])

    result = shell('files_menu')
    assert result.returncode == 0, result.stderr
    assert (work / "opened").read_bytes() == b"--\0" + str(attached).encode() + b"\0"
    result = shell('files_menu "$XDG_RUNTIME_DIR/selection"', TEST_CANCEL="1")
    assert result.returncode == 1 and not (work / "selection").exists()

    # Real live event handling copies answers and hands follow-ups back to the menu.
    result = shell('''
ai_live <<'EVENTS'
{"name":"select entry","value":"Copy answer"}
{"name":"select entry","value":"Follow-up"}
EVENTS
''')
    assert result.returncode == 0, result.stderr
    assert (work / "copied").read_text() == "Test answer"
    assert (work / "dots-utils/ai-action").read_text().strip() == "followup"
    assert '"Follow-up"' in result.stdout

    # Cancel closes the live stream and stops its systemd unit; stale jobs become errors.
    running = work / "dots-utils/ai.json"
    running.write_text(json.dumps({"status": "running", "answer": "Partial <answer>"}))
    (work / "active").touch()
    result = shell('''ai_live <<'EVENTS'
{"name":"select entry","value":"Cancel"}
EVENTS
''')
    assert result.returncode == 0, result.stderr
    assert "Partial &lt;answer&gt;" in result.stdout
    assert not (work / "active").exists()
    result = shell('"$ROOT/modi/ai.sh" status')
    assert json.loads(result.stdout)["status"] == "error"

print("Rofi AI checks passed: streaming, context, attachments, clipboard, Files, and live actions.")

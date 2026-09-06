#!/usr/bin/env python3
"""Check the repository's OpenCode setup; --runtime also checks installed OpenCode.

Runtime checks use a temporary copy with isolated XDG directories. They do not
activate configuration or read provider credentials. --smoke additionally sends
a synthetic read-tool request to the configured local model.
"""

import argparse
import ast
from fnmatch import fnmatchcase
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / ".config/opencode"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def effective(rules, tool, value):
    matches = [rule["action"] for rule in rules
               if fnmatchcase(tool, rule["permission"])
               and fnmatchcase(value, rule["pattern"])]
    return matches[-1] if matches else "ask"


def static_checks():
    config = json.loads((CONFIG / "opencode.json").read_text())
    json.loads((CONFIG / "tui.json").read_text())
    agents = {}
    for path in sorted((CONFIG / "agents").glob("*.md")):
        parts = path.read_text().split("---", 2)
        require(len(parts) == 3 and not parts[0].strip(), f"Missing frontmatter: {path}")
        require(parts[2].strip(), f"Empty agent prompt: {path}")
        for field in ("description", "mode"):
            require(re.search(rf"^{field}: .+", parts[1], re.M), f"Missing {field}: {path}")
        agents[path.stem] = parts[1]
    require(config["default_agent"] in agents, "Unknown default agent")
    require("mode: primary" in agents[config["default_agent"]], "Default must be primary")
    for name, command in config["command"].items():
        require(command.get("agent") in agents, f"Unknown or missing agent for /{name}")
        require("$ARGUMENTS" in command["template"], f"/{name} drops user arguments")
    for command, agent in {"test": "tester", "docker": "devops", "plan": "plan",
                           "commit": "git", "research": "research"}.items():
        require(config["command"][command]["agent"] == agent, f"Wrong /{command} routing")
    require("init" not in config["command"], "Custom /init shadows built-in initialization")
    require(config["lsp"] is True, "Use built-in LSP discovery to avoid duplicate servers")
    require(config["formatter"] is True, "Use project-aware built-in formatters")
    for path in (CONFIG / "scripts/mtg").glob("mtg-*"):
        ast.parse(path.read_text(), filename=str(path))
    print(f"Static checks passed: {len(agents)} agents, {len(config['command'])} commands, JSON and helper syntax")
    return config, agents


def runtime_checks(config, names, smoke=False, model_timeout=600):
    binary = shutil.which("opencode")
    require(binary, "opencode is not installed; run --runtime on the Arch laptop")
    with tempfile.TemporaryDirectory(prefix="dots-opencode-check.") as temporary:
        root = Path(temporary)
        isolated = root / "config/opencode"
        shutil.copytree(CONFIG, isolated, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        workspace = root / "workspace"
        workspace.mkdir()
        # Drop user OpenCode overrides so these checks exercise only this copy.
        env = {key: value for key, value in os.environ.items() if not key.startswith("OPENCODE_")}
        env.update({
            "XDG_CONFIG_HOME": str(root / "config"),
            "XDG_DATA_HOME": str(root / "data"),
            "XDG_CACHE_HOME": str(root / "cache"),
            "XDG_STATE_HOME": str(root / "state"),
            "OPENCODE_CONFIG_DIR": str(isolated),
            "OPENCODE_DISABLE_PROJECT_CONFIG": "true",
            "OPENCODE_DISABLE_CLAUDE_CODE": "true",
            "OPENCODE_DISABLE_EXTERNAL_SKILLS": "true",
            "OPENCODE_DISABLE_MODELS_FETCH": "true",
        })

        def run(*args, timeout=120):
            result = subprocess.run([binary, *args], cwd=workspace, env=env,
                                    text=True, capture_output=True, timeout=timeout)
            require(result.returncode == 0, f"opencode {' '.join(args)} failed:\n{result.stderr}")
            return result.stdout

        version = run("--version").strip()
        resolved = json.loads(run("debug", "config"))
        require(resolved["default_agent"] == config["default_agent"], "Default agent did not resolve")
        require(resolved["model"] == config["model"], "Local model changed during resolution")
        require(resolved["command"] == config["command"], "Commands changed during resolution")
        analysis = {"plan", "explore", "research", "architect", "code-reviewer", "security"}
        for name in names:
            agent = json.loads(run("debug", "agent", name))
            rules = agent["permission"]
            require(agent.get("prompt"), f"{name}: prompt not loaded")
            if name in analysis:
                require(effective(rules, "edit", "src/example.py") == "deny", f"{name}: edits allowed")
                require(effective(rules, "bash", "python3 -c 'print(1)'") == "deny", f"{name}: shell unrestricted")
                require(effective(rules, "task", "build") == "deny", f"{name}: can delegate implementation")
            else:
                require(effective(rules, "bash", "git push") in {"ask", "deny"}, f"{name}: push bypass")
                require(effective(rules, "bash", "rm -rf /") == "deny", f"{name}: root deletion bypass")
            if name == "build":
                require(effective(rules, "edit", "src/example.py") == "allow", "Build cannot edit")
                require(effective(rules, "bash", "python3 -m unittest") == "allow", "Build cannot test")
                require(effective(rules, "bash", "git commit -m fix") == "allow", "Explicit /commit would reprompt")
            if name in {"style", "verifier", "mtg-deck", "mtg-rules"}:
                require(effective(rules, "edit", "src/example.py") == "deny", f"{name}: unexpected edits")
            print(f"  {name}: loaded; permission checks passed", flush=True)
        print(f"OpenCode {version}: runtime configuration and agent checks passed")
        if smoke:
            require(config["provider"]["llamacpp"]["options"]["baseURL"] == "http://127.0.0.1:8080/v1",
                    "Smoke test requires the configured loopback model endpoint")
            marker = "opencode-probe-" + os.urandom(8).hex()
            (workspace / "probe.txt").write_text(marker + "\n")
            output = run("run", "--agent", "build", "--format", "json",
                         "--title", "OpenCode configuration smoke test",
                         f"Use the read tool to read {workspace / 'probe.txt'}. "
                         "Reply with its exact contents. Do not edit files or use other tools.",
                         timeout=model_timeout)
            events = [json.loads(line) for line in output.splitlines() if line.startswith("{")]
            for event in events:
                part = event.get("part", {})
                if event.get("type") == "tool_use":
                    print(f"  Model tool: {part.get('tool')}; state: {part.get('state', {}).get('status')}", flush=True)
                elif event.get("type") == "step_finish":
                    print(f"  Model step: {part.get('reason')}; tokens: {part.get('tokens')}", flush=True)
            require(not any(event.get("type") == "error" for event in events), "Model returned an error")
            require(any(event.get("type") == "tool_use" and event.get("part", {}).get("tool") == "read"
                        and event["part"].get("state", {}).get("status") == "completed" for event in events),
                    "Model did not complete the requested read-tool call. CLI output:\n" + output[-3000:])
            require(any(event.get("type") == "text" and marker in event.get("part", {}).get("text", "")
                        for event in events), "Model did not return the synthetic file contents. CLI output:\n" + output[-6000:])
            require((workspace / "probe.txt").read_text() == marker + "\n", "Model changed the probe")
            print("Local model smoke test passed: read tool completed and synthetic contents returned")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", action="store_true", help="Validate with installed OpenCode in isolated temporary directories")
    parser.add_argument("--smoke", action="store_true", help="Also test a synthetic read-tool call against the local model (implies --runtime)")
    parser.add_argument("--model-timeout", type=int, default=600, help="Smoke-test timeout in seconds (default: 600 for the local model)")
    args = parser.parse_args()
    if args.model_timeout <= 0:
        parser.error("--model-timeout must be positive")
    try:
        config, agents = static_checks()
        if args.runtime or args.smoke:
            runtime_checks(config, agents, smoke=args.smoke, model_timeout=args.model_timeout)
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        parser.exit(1, f"OpenCode check failed: {error}\n")


if __name__ == "__main__":
    main()

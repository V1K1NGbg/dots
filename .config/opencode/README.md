# OpenCode

Reusable OpenCode configuration with a local model provider:
`llamacpp/qwen3.8-27b-uncensored` at `http://127.0.0.1:8080/v1`, with a 32,768-token
context and an 8,192-token output limit. The installer manages the corresponding
`llama-cpp.service`. No provider credentials belong in this directory.

## Daily use

- **Build** is the default: investigate, implement, and verify a requested change.
- **Plan** or `/plan` investigates and proposes changes without implementing.
- `/debug`, `/frontend`, `/test`, `/docs`, and `/devops` handle specialized work.
- `/explore`, `/review`, `/security`, `/research`, and `/architect` analyze without
  editing. Their shell access is limited to Git inspection. Use `/verify` for
  execution-based validation; tests may create artifacts, but it must not edit source.
- `/commit` authorizes a new local commit of relevant changes. Publishing remains
  separate. `/pr` prepares a pull request and checks publication authorization.
- `/new-project` scaffolds a project. The built-in `/init` remains available for
  generating project instructions.
- `/mtg-card` performs a lookup; `/mtg` handles Commander decks; `/mtg-rules` checks
  rules against live sources. Full deck planning applies only to deck-building work.
- `/write` reads the private `~/.config/opencode/style/about.md` profile before
  drafting. If it cannot be read, report that instead of silently omitting it.

Commands are defined in `opencode.json`; agent prompts and permissions live in
`agents/`. Keep common behavior in `AGENTS.md` and role-specific guidance in each
agent. Agents inherit the selected model. Choose delegation concurrency according
to the configured provider’s capacity.

## Configuration choices

Shared permissions live in `opencode.json`. Implementation agents inherit them
instead of appending an allow-all shell rule that overrides shared restrictions.
Analysis agents explicitly restrict edits, shell execution, and delegation.
These command patterns are guardrails, not a filesystem or process sandbox.
Project configuration can override global configuration; inspect the resolved
agent when troubleshooting permission behavior.

Built-in LSP discovery and formatters follow supported server IDs and project
tooling. They avoid the former duplicate `python`/`pyright` and `go`/`gopls`
definitions and global formatter commands that could ignore project choices.
Install the relevant project tooling and formatter configuration when needed;
formatting does not run every possible formatter on every project.

OpenCode automatically discovers `AGENTS.md` and its supported `CLAUDE.md`
fallback. Extra instruction paths retain `INSTRUCTIONS.md`,
`.opencode/instructions.md`, and `.github/copilot-instructions.md`.
Local skills are discovered in OpenCode's standard locations and `~/.skills`.
Skill-directory websites are not configured as remote indexes: `skills.urls`
expects a compatible `index.json` and skill files, not a catalog home page.

Automatic compaction and pruning are enabled, with a 4,096-token reserve.
The model, manual sharing, disabled auto-update, and TUI appearance are preserved.

## Validation

From the repository root, run the static checks:

```sh
python3 scripts/check-opencode.py
```

On a machine with OpenCode installed, also check runtime configuration loading:

```sh
python3 scripts/check-opencode.py --runtime
```

Repository-specific remote testing instructions are in the root `README.md`.

Add `--smoke` to also make one synthetic read-tool request against the local
model server. This checks tool execution and response handling without sending
repository content to a model. The service must already be running.

The runtime check copies this configuration into temporary XDG directories,
loads it with the installed OpenCode, and checks resolved agent permissions.
It does not change the active configuration; model requests require `--smoke`. It validates config
loading and representative permission cases, not model quality or every shell
spelling. The static check also parses the MTG Python helpers; it does not
certify remote APIs or the deck validator's full rules coverage.

For the active setup, `opencode debug agent build` and `opencode debug agent plan`
show resolved permissions. Avoid sharing complete resolved configuration output
if you add private provider settings later.

Apply tested changes by backing up the affected active files and copying only
the changed files into `~/.config/opencode`. Preserve local profiles, credentials,
skills, and unrelated settings. Start a new OpenCode process to load changes;
do not interrupt an existing session or restart the model service for prompt edits.

## Sources

- [Configuration and precedence](https://opencode.ai/docs/config/)
- [Agents](https://opencode.ai/docs/agents/) and [permissions](https://opencode.ai/docs/permissions/)
- [Commands](https://opencode.ai/docs/commands/)
- [LSP servers](https://opencode.ai/docs/lsp/) and [formatters](https://opencode.ai/docs/formatters/)
- [Skills](https://opencode.ai/docs/skills/)

# Changelog

## Unreleased

- Make OpenCode files reusable by removing the fixed username, machine-specific
  guidance, concrete deck examples, and bytecode containing personal paths.

- Remove the competitive-programming agent and `/cp` command; retain the Java
  templates. Restore the writing profile as a required source.

- Rework OpenCode's shared instructions and the retained 18 agents, make Build the default,
  restrict Plan to analysis, and route commands to their intended specialists.
- Consolidate OpenCode permissions, use built-in LSP/formatter discovery, remove
  catalog URLs from skill discovery, and clarify MTG and writing workflows.
- Add `scripts/check-opencode.py` and an OpenCode configuration guide.
- Add password-free SSH inspection and working-tree snapshot transfer to the
  Arch test laptop using `scripts/laptop-dev.py`.
- Document separate laptop testing and `v1.2.x` release tags.

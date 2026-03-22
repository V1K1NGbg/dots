# Global OpenCode Rules

## Code Standards

### General
- Write clean, readable code. Clarity over cleverness.
- Use meaningful variable and function names. No single-letter names except in tight loops or math formulas.
- Keep functions short and focused. If a function needs a comment explaining what it does, it should be renamed or split.
- Handle errors explicitly. Never silently swallow exceptions.
- Write tests for non-trivial logic.

### TypeScript / JavaScript
- Use TypeScript with strict mode.
- Prefer `const` over `let`. Never use `var`.
- Use async/await over raw promises. Avoid callback hell.
- Use early returns to reduce nesting.
- Prefer functional array methods (map, filter, reduce) over for loops when appropriate.
- Use template literals over string concatenation.

### Python
- Follow PEP 8.
- Use type hints for function signatures.
- Prefer f-strings over format() or %.
- Use context managers (with statements) for resource management.
- Use dataclasses or Pydantic for structured data.

### Rust
- Follow the Rust API guidelines.
- Use Result and Option instead of panicking.
- Prefer zero-copy operations where possible.
- Write documentation tests.

### C / C++
- Follow modern C++ practices (C++17 minimum).
- Use RAII for resource management.
- Prefer smart pointers over raw pointers.
- Use const correctness throughout.

## Git Practices
- Write conventional commit messages: `type(scope): description`
- Types: feat, fix, refactor, docs, test, chore, perf, ci, style, build
- Keep commits atomic -- one logical change per commit
- Write meaningful commit messages that explain WHY, not just WHAT
- Never commit secrets, credentials, or .env files
- Branch naming: `feature/description`, `fix/description`, `chore/description`

## Communication Style
- Be direct and concise
- Technical precision matters
- Show work: explain reasoning, not just conclusions
- When uncertain, say so explicitly
- Provide actionable suggestions, not vague advice

## Project Context
- I often work with: TypeScript, Python, Rust, C, Docker, Node.js, Bun
- I run Minecraft servers on Docker
- I use Linux as my primary development environment
- I prefer terminal-based tools and CLI workflows

## Docker Best Practices
- Always use multi-stage builds to minimize final image size.
- Pin base image versions (`node:22.12-alpine`, not `node:latest`).
- Use Alpine or distroless images when possible.
- Run as non-root user. Always add `USER` directive.
- Order Dockerfile instructions by change frequency (least changing first) to maximize layer caching.
- Combine RUN commands to reduce layers. Use `&&` to chain commands.
- Use `.dockerignore` to exclude `node_modules`, `.git`, build artifacts.
- Never store secrets in images. Use build args or runtime env vars.
- Use `HEALTHCHECK` for production containers.
- Prefer `COPY` over `ADD` unless you need tar extraction or URL fetching.
- Set explicit `WORKDIR` instead of using absolute paths.
- Use `--no-cache` flags for package managers in build (`apt-get install --no-cache`, `pip install --no-cache-dir`).

## Testing Philosophy
- Test behavior, not implementation. Tests should survive refactors.
- Name tests descriptively: `test_should_return_404_when_user_not_found` over `test_get_user`.
- Each test should test ONE thing. If it needs "and" in the name, split it.
- Use the Arrange-Act-Assert (AAA) pattern.
- Prefer integration tests for API endpoints, unit tests for business logic.
- Mock external dependencies (APIs, databases), not internal modules.
- Test edge cases: empty inputs, boundary values, null/undefined, concurrent access.
- Tests are documentation. Someone should understand the feature by reading the tests.
- Don't test framework code or third-party libraries.
- Aim for meaningful coverage, not 100% line coverage. Focus on critical paths.

## Error Messages
- Error messages must answer three questions: What happened? Why? What can the user do about it?
- Include relevant context: file paths, expected vs actual values, relevant identifiers.
- Use consistent error codes or types for programmatic handling.
- Never expose internal implementation details (stack traces, SQL queries) to end users.
- Log the full error with stack trace server-side; show a clean message to the user.
- For CLI tools: exit with non-zero codes and write errors to stderr.
- For APIs: use consistent error response format with `error`, `message`, and optional `details` fields.

## Shell Scripting
- Always start scripts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Quote all variable expansions: `"$var"` not `$var`.
- Use `[[ ]]` over `[ ]` for conditionals.
- Use `$(command)` over backticks for command substitution.
- Write shellcheck-clean scripts. Run `shellcheck` before committing.
- Use `readonly` for constants.
- Use `local` for function variables.
- Provide `--help` output for any script with arguments.
- Use `trap` for cleanup on exit.
- Prefer long flag names for readability (`--verbose` over `-v` in scripts).

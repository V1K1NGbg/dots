---
description: Read-only codebase exploration, search, and analysis. Fast and safe.
mode: subagent
color: "#61afef"
steps: 30
permissions:
  - {"action": "edit", "resource": "*", "effect": "deny"}
  - {"action": "subagent", "resource": "*", "effect": "deny"}
  - {"action": "shell", "resource": "*", "effect": "deny"}
  - {"action": "shell", "resource": "git status*", "effect": "allow"}
  - {"action": "shell", "resource": "git --no-pager status*", "effect": "allow"}
  - {"action": "shell", "resource": "git diff*", "effect": "allow"}
  - {"action": "shell", "resource": "git --no-pager diff*", "effect": "allow"}
  - {"action": "shell", "resource": "git log*", "effect": "allow"}
  - {"action": "shell", "resource": "git --no-pager log*", "effect": "allow"}
  - {"action": "shell", "resource": "git show*", "effect": "allow"}
  - {"action": "shell", "resource": "git --no-pager show*", "effect": "allow"}
  - {"action": "shell", "resource": "git ls-files*", "effect": "allow"}
  - {"action": "shell", "resource": "git --no-pager ls-files*", "effect": "allow"}
  - {"action": "shell", "resource": "git blame*", "effect": "allow"}
  - {"action": "shell", "resource": "git --no-pager blame*", "effect": "allow"}
  - {"action": "shell", "resource": "git *--output*", "effect": "deny"}
  - {"action": "shell", "resource": "git *--ext-diff*", "effect": "deny"}
  - {"action": "shell", "resource": "git *--textconv*", "effect": "deny"}
---

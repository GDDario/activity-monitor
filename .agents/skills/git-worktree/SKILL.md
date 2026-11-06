---
name: git-worktree
description: Create, prepare, or run an isolated Activity Monitor Flutter Git worktree, including worktree-specific runtime ports.
---

# Git worktree

Read the shared `.opencode/skills/git-worktree/SKILL.md` and use its repository scripts for worktree creation and isolated Flutter ports. Its OpenCode tool and session-move instructions apply only to OpenCode; use the tools and permissions available in the current Codex session instead.

After creating or selecting a worktree, move the current Codex session to it if the host exposes a supported session-move capability. Otherwise, use the worktree as the working directory for subsequent work, request filesystem permissions when required, and clearly report that the session itself has not moved. Do not claim that setting a command's working directory moves the session.

After creating a worktree, include a ready-to-run `codex -C <absolute-worktree-path>` command in the final response. Shell-quote the path when necessary.

Connect Dart MCP for runtime inspection when it is available; otherwise report the limitation. Follow the repository instructions and run checks appropriate to the actual work performed.

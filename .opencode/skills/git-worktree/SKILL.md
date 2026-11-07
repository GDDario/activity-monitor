---
name: Git Worktree
description: Create and run an isolated Activity Monitor Flutter worktree with its own ports and Dart MCP connection.
---

# Git Worktree

Use this skill when creating, switching to, or running a parallel Activity
Monitor development worktree.

## Project guarantees

- Git ignores Flutter's generated `.dart_tool/`, `build/`, and plugin state, so
  every worktree has independent generated artifacts.
- `.opencode/opencode.jsonc` starts the Dart MCP server with `cwd: "./app"`
  when OpenCode starts at a worktree root. `app/.opencode/opencode.jsonc` does
  the equivalent for an app-root session. Do not replace either relative path
  with a path from another worktree.
- The Dart MCP server communicates over stdio and therefore has no TCP port to
  allocate. A running Flutter application does use web, browser-debugging, VM
  service, DDS, and DTD endpoints.

## Create the worktree

Create a branch worktree and independently resolve Flutter packages. By default,
the script places it under `../activity-monitor.worktrees/` relative to the main
checkout, even when invoked from another worktree. Branch name slashes become
hyphens in the directory name:

```bash
.opencode/skills/git-worktree/scripts/create_worktree.sh \
  feature/my-change
```

Pass an optional destination and start point when needed:

```bash
.opencode/skills/git-worktree/scripts/create_worktree.sh \
  feature/my-change ../activity-monitor.worktrees/custom-name origin/main
```

Use the repository script to ensure the default destination is respected. When
using OpenCode, move the active session with `opencode.session_move` only after
the user asks to work there.

## Run Flutter without port collisions

Run the helper **from the target worktree root**. It derives a worktree-specific
candidate range and skips occupied ranges.

```bash
.opencode/skills/git-worktree/scripts/run_flutter.sh --device chrome
```

For Linux desktop:

```bash
.opencode/skills/git-worktree/scripts/run_flutter.sh --device linux
```

The helper always supplies `--print-dtd`, `--host-vmservice-port`, and
`--dds-port`. For Chrome and web-server targets, it also supplies `--web-port`
and `--web-hostname 127.0.0.1`; Chrome additionally receives
`--web-browser-debug-port`.
It prints every allocated port before Flutter starts. Pass normal `flutter run`
arguments after `--`, for example `-- --dart-define=API_URL=http://localhost`.

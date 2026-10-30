# Worktree Development Environment

## Problem

Developers need to work on multiple Flutter branches at the same time without
sharing generated files, development-server ports, or Dart debugging services.

## Expected behavior

- A developer can create a branch worktree adjacent to the repository.
- The new worktree initializes the Flutter package dependencies independently.
- A Flutter process launched for a worktree uses ports that are distinct from
  other active worktrees for every applicable local endpoint.
- The launch command prints a Dart Tooling Daemon (DTD) address so the local
  Dart MCP server can connect to the application.
- The project OpenCode configurations continue to start the Dart MCP server in
  the `app/` directory when OpenCode starts at either repository root or app
  root in any worktree.

## Business rules

- The helper MUST not modify or remove existing worktrees.
- The helper MUST reject an unsafe branch name or a pre-existing destination.
- Chrome launches MUST assign unique web-server and browser-debugging ports, in
  addition to Dart VM service and DDS ports. Web-server launches MUST assign a
  unique web-server port in addition to Dart VM service and DDS ports.
- Non-web launches MUST assign unique Dart VM service and DDS ports.

## Acceptance criteria

1. The project contains the discoverable `git-worktree` OpenCode skill and a
   `/worktree` command for creating and using a Flutter worktree.
2. The skill provides a helper for branch worktree creation and dependency
   initialization.
3. The skill provides a helper that selects available local ports and launches
   Flutter with `--print-dtd`.
4. The helpers are valid Bash scripts and can create an isolated verification
   worktree without changing the current worktree.

## Edge cases

- If the requested branch already exists, it is checked out rather than
  recreated.
- If the branch is active in another worktree, Git rejects the operation rather
  than allowing two worktrees to share it.
- If a candidate port is occupied, another four-port range is selected.

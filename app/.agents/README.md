# Flutter AI tooling

This directory contains portable AI-assistant resources for the Flutter app.
OpenCode is configured separately in `../.opencode/opencode.jsonc` and
`.opencode/opencode.jsonc` so it works whether it starts at the repository
root or in this directory.

## Dart and Flutter MCP server

`mcp_config.json` configures the Dart and Flutter MCP server for assistants
that use this generic configuration format. It enables application lifecycle,
test, and formatting tools in addition to the server's default analysis,
symbol, package, and runtime-inspection tools.

OpenCode does not read `mcp_config.json`. Its native configuration is in the
two `.opencode/opencode.jsonc` files described above.

AI clients use different configuration locations. Clients that support the
standard `mcpServers` format can use the `dart` entry from
`mcp_config.json`. For example, GitHub Copilot in VS Code uses
`.vscode/mcp.json`; follow your client's MCP setup instructions and copy the
entry there if it does not discover this file automatically.

## Official skills

Run these commands from this `app/` directory to install the official skills
into `.agents/skills/`:

```bash
npx skills add flutter/agent-plugins --skill '*' --agent universal --yes
npx skills add dart-lang/skills --skill '*' --agent universal --yes
```

The skills are intentionally not vendored until they are installed. Update them
by rerunning the same commands. Validate installed or locally authored skills
with:

```bash
dart run skills_lint
```

## Package skills

After dependencies are added or updated, discover package-provided skills with:

```bash
dart run skills@ get
```

Only install skills from dependencies you trust.

## References

- <https://docs.flutter.dev/ai/tools>
- <https://docs.flutter.dev/ai/get-started>

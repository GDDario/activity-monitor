# Activity Monitor Flutter app instructions

## Required project context

Before changing production code, read the following project documents from the
repository root:

- `../docs/spec/project/constitution.md`
- `../docs/spec/project/architecture.md`
- `../docs/spec/project/conventions.md`

Non-trivial behavior requires a feature specification under
`../docs/spec/features/` before implementation. Follow Red-Green-Refactor:
write a failing behavior test, make the smallest change that passes it, then
refactor without changing observable behavior.

## Flutter and Dart workflow

- Use installed skills under `.agents/skills/` when their task matches.
- Prefer the Dart MCP server for analysis, symbol information, dependency work,
  formatting, tests, and runtime inspection when it is available.
- Before launching a Flutter app for agent-assisted debugging, pass
  `--print-dtd` so the Dart MCP server can connect to it.
- After a meaningful edit to `lib/**/*.dart`, discover a running app through
  the Dart Tooling Daemon and hot reload it when possible. Hot restart instead
  after edits to `main()`, initialization, or global/static state. Do not
  reload for documentation-, whitespace-, or test-only changes.
- Run `dart format .`, `flutter analyze`, and `flutter test` before completing
  a change.

## Architecture constraints

- Preserve the View -> ViewModel -> Use Case -> Repository -> Service flow and
  unidirectional data flow.
- Views must not access repositories or services. ViewModels must not depend on
  services. Use cases must not depend on services. Repositories must not depend
  on other repositories.
- Keep domain code independent of Flutter and infrastructure. Use constructor
  injection at composition boundaries.
- Treat all external input as untrusted. Do not commit secrets or expose
  sensitive data in logs, errors, or telemetry.

# Application Foundation Plan

## Architecture impact

Read `docs/spec/project/constitution.md`,
`docs/spec/project/architecture.md`, and
`docs/spec/project/conventions.md` before implementation. No ADR applies.

The composition boundary under `app/lib/app/` will own application-wide
dependency construction. The root application widget will consume only the
router configuration. The dashboard remains a View and retains no access to
repositories or services. No domain operation is introduced, so no Use Case or
Repository is needed for this foundation work.

## Data model changes

No domain models, persistence, or migrations are added. A UUID v7 generator is
made available at the composition boundary for future repositories; it does not
generate an identifier until a feature requires one.

## Application contracts

- Router configuration: resolves `/` to the dashboard View and resolves
  unknown locations to a safe fallback View.
- HTTP client factory: provides one configured low-level HTTP client for future
  Services; it is not used by Views or ViewModels.
- UUID factory: provides an identifier generator capable of UUID v7 generation
  for future injected Repository dependencies.
- Application feedback host: provides the common presentation infrastructure
  for future ViewModels to surface safe feedback through Views.

## Patterns to follow

[ASSUMPTION: use Riverpod providers only at the composition boundary until a
feature introduces state-owning ViewModels.] Generated immutable models and
JSON serialization are configured as build capabilities but are not introduced
without an owning domain or DTO model.

## Testing strategy

Follow Red-Green-Refactor. Add a widget test that fails before the application
root is migrated, then verifies the routed dashboard, supported locale, and
feedback host. Add focused tests for the HTTP and identifier composition
factories without invoking network I/O. Run `dart format .`, `flutter analyze`,
and `flutter test`.

## Security and performance constraints

No credentials, authorization headers, endpoints, or request logging are
configured. Future Services MUST treat responses as untrusted and MUST NOT log
sensitive values. The HTTP client has finite connection and receive timeouts.
`[ASSUMPTION: a 15-second timeout is appropriate until a remote API contract
exists.]`

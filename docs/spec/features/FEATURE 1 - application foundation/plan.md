# SECTION 2: PLAN

## Architecture impact

Before implementation, read `docs/spec/project/constitution.md`,
`docs/spec/project/architecture.md`, and `docs/spec/project/conventions.md`.
Read `docs/spec/project/design-reference.md` before UI work. No applicable ADR
exists. This Feature 1 specification is the source of truth; implementation
MUST satisfy it or the specification MUST be updated first.

The application composition boundary under `app/lib/app/` owns router,
localization, feedback host, and dependency construction. Extend the existing
`DashboardView` with a responsive application shell that routes to Today,
People, Calendar, and Profile. Preserve the current Today dashboard. Put shared
theme, navigation, title-area, and empty-state widgets in `app/lib/ui/core/`;
put base destination Views in their respective `app/lib/ui/` directories.

No ViewModel, Use Case, Repository, Service, data model, persistence, or schema
migration is needed for this presentation-only foundation. Future data-backed
work MUST follow View → ViewModel → Use Case → Repository → Service with
unidirectional data flow and an ADR before SQLite is introduced.

## Data model changes

No domain models, persistent data, migrations, or entity identifiers are added.
The existing Today preview remains presentation-only. `[ASSUMPTION: a future
feature will introduce SQLite through an approved ADR before any durable user
data is created.]`

## Application contracts

- Router resolves `/` to Today, resolves People, Calendar, and Profile to their
  base Views, and uses a safe fallback for unknown locations.
- Application feedback host provides one accessible, presentation-safe location
  for transient messages.
- Localization provides United States English and Brazilian Portuguese resources
  with a supported-locale fallback.
- Title-area calendar access routes to Calendar; notification access is visibly
  unavailable or produces a safe unavailable message until a notification
  feature defines its behavior; profile image or abbreviation access routes to
  Profile.

## Patterns to follow

- Use `ActivityMonitorApp`, `appRouterProvider`, `ActivityTheme`,
  `ActivityCard`, and `SectionHeader` as existing patterns.
- Use `ThemeData` and `ColorScheme` for design tokens, `LayoutBuilder` for
  compact/wide layout selection, constrained wide content, and reusable shared
  widgets under `ui/core/`.
- Apply the Mindful Editorial Productivity reference: warm neutral surfaces,
  forest-green emphasis, calm editorial hierarchy, soft geometry, visible focus
  states, and restrained feedback.
- `[ASSUMPTION: existing Riverpod composition remains sufficient and may evolve
  as application behavior is added.]`

## Testing strategy

Follow Red-Green-Refactor: add one focused failing behavior test, implement the
minimum passing code, then refactor without observable change. Widget-test the
theme, accessible labels, routed screens, active navigation, title area,
compact/wide behavior, empty-state descriptions, and unknown-route fallback.
No repository, service, migration, or domain tests are required because this
feature owns no data behavior.

Before completion, run `dart format .`, `flutter analyze`, and `flutter test`.
All existing tests, acceptance criteria, and documentation MUST remain aligned.

## Security and performance constraints

Do not include real profile images, personal details, remote resources, secrets,
or telemetry in the preview or empty Views. User-facing failure messages MUST
not expose technical details. Keep responsive layouts bounded and avoid
unnecessary data loading. `[ASSUMPTION: the foundation has no authentication,
authorization, synchronization, or remote-data boundary.]`

# SECTION 2: PLAN

## Architecture impact

Before implementation, read `docs/spec/project/constitution.md`,
`docs/spec/project/architecture.md`, and `docs/spec/project/conventions.md`.
Read `docs/spec/project/design-reference.md` before UI work. No applicable ADR
exists. This Feature 1 specification is the source of truth; implementation
MUST satisfy it or the specification MUST be updated first.

The application composition boundary under `app/lib/app/` owns router,
localization, feedback host, dependency construction, HTTP client, and UUIDv7
generator. Extend the existing `DashboardView` into a responsive shell that
routes to Today, People, Calendar, Profile, and a selected-day view. Preserve
the current Today dashboard during base-routing work. Put shared theme and
widgets in `app/lib/ui/core/`, and feature Views/ViewModels in their respective
`app/lib/ui/` directories.

Presentation-only visual foundation work needs no ViewModel, Use Case,
Repository, or Service. Data-backed activity, people, calendar, and profile
behavior follows View → ViewModel → Use Case → Repository → Service with
unidirectional data flow. Views MUST NOT access repositories or services;
ViewModels and Use Cases MUST NOT depend on services; repositories MUST NOT
depend on one another. Dependencies are constructor-injected at composition.

## Data model changes

- The visual preview uses immutable private presentation records only until
  data-backed activities are implemented.
- Add immutable `Activity`, `ScheduledActivity`, `ActivityId`,
  `ScheduledActivityId`, `Person`, `PersonId`, `Collaboration`,
  `FocusSessionDraft`, `Profile`, `ThemePreference`, and `LanguagePreference`
  for data-backed behavior. Generate new persisted IDs with injected UUIDv7.
- `ScheduledActivity` owns its activity reference, local date, completion state,
  planned positive duration, scheduled time, and list presentation fields;
  removal unschedules it rather than deleting `Activity`.
- Add repository-owned local persistence and forward-only versioned migrations
  for activities, daily scheduling, people, collaborations, and profile
  preferences. Enforce keys, required fields, positive duration, completion
  state, and supported foreign keys. Migrations MUST document rollback and
  preserve existing records. `[ASSUMPTION: local durable persistence is the
  offline-first single source of truth.]`
- Persist intended local calendar dates without deriving them incorrectly from
  instants. `[ASSUMPTION: scheduling uses the device's current time zone until
  cross-time-zone behavior is specified.]`

## Application contracts

- Router resolves `/` to Today, routes People, Calendar, Profile, and a
  selected-day daily view, and uses a safe fallback for unknown locations.
- Application feedback host provides one accessible, presentation-safe location
  for transient messages; the HTTP and UUID factories are replaceable and are
  not accessed from Views or ViewModels.
- `GetDayActivities(LocalDate)` returns a daily summary and ordered entries.
  `SetScheduledActivityCompletion`, `UpdateScheduledActivity`, and
  `RemoveActivityFromDay` return updated data or explicit `notFound`/
  validation failures.
- `CreateFocusSessionDraft(ScheduledActivityId)` returns a draft initialized
  from planned duration or `durationRequired`/`notFound`. `[ASSUMPTION: a later
  focus feature owns persistence and timing of started sessions.]`
- `SearchPeople(query, sort, page)` returns bounded collaboration summaries and
  page metadata. `GetCalendarActivityCounts(CalendarRange)` returns counts by
  local day. `[ASSUMPTION: Calendar initially shows one month at a time.]`
- `GetProfile`, `UpdateProfile`, and `SelectProfileImage` return the current or
  updated profile, explicit validation failures, or a presentation-safe media
  failure. Profile image input MUST be validated before a local reference is
  stored.

## Patterns to follow

- Use `ActivityMonitorApp`, `appRouterProvider`, `ActivityTheme`,
  `ActivityCard`, and `SectionHeader` as the existing patterns.
- Use `ThemeData` and `ColorScheme` for design tokens, `LayoutBuilder` for
  compact/wide layout selection, constrained wide content, and reusable shared
  widgets under `ui/core/`.
- Apply the Mindful Editorial Productivity reference: warm neutral surfaces,
  forest-green emphasis, calm editorial hierarchy, soft geometry, visible focus
  states, and restrained feedback.
- Use one immutable state object and intent-named commands for each non-trivial
  ViewModel. `[ASSUMPTION: existing Riverpod composition remains sufficient and
  no state-management dependency is added.]`

## Testing strategy

Follow Red-Green-Refactor: add one focused failing behavior test, implement the
minimum passing code, then refactor without observable change. Widget-test the
visual theme, accessible labels, routed screens, active navigation,
compact/wide behavior, empty states, swipes, confirmation, calendar selection,
and profile controls. Domain and Use Case tests cover invariants; use fakes for
repositories and mocks only at boundaries. Test concrete repositories and
migrations against real local SQLite where persistence matters.

Before completion, run `dart format .`, `flutter analyze`, and `flutter test`.
All existing tests, acceptance criteria, and documentation MUST remain aligned.

## Security and performance constraints

Treat names, tags, queries, preferences, and selected media as untrusted.
Validate media type, accessibility, and size; do not log user content, media
paths, secrets, or technical errors in presentation messages. `[ASSUMPTION:
the initial release has one local profile, no remote synchronization, and no
authorization boundary.]`

Use bounded and indexed date/collaboration queries, paged People results, and
data-source aggregation for visible calendar ranges. Do not decode full-size
profile images in list rows or load unbounded histories into ViewModels.

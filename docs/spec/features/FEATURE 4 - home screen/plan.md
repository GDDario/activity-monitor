# SECTION 2: PLAN

## Status and required context

**Approved.** The user approved this plan and P01–P04, and explicitly requested
creating the checklist and continuing implementation in the same session.
The specification and H01–H07 remain approved. Implementation and fresh
acceptance results are recorded in [tasks.md](tasks.md).

The implementing agent MUST read the [constitution](../../project/constitution.md)
always, [architecture](../../project/architecture.md) and
[SQLite ADR](../../../adr/0001-use-sqlite.md) for structural/data decisions,
[conventions](../../project/conventions.md) before production changes, and
[design reference](../../project/design-reference.md) plus the Home Stitch HTML
and image before UI work. Follow root and app `AGENTS.md`. Keep temporary logs,
captures and working artifacts under `.scratches/`.

## Architecture impact

Preserve the existing View → ViewModel → Use Case → Repository → Service flow:

- `DashboardView` renders one immutable `TodayState` from `TodayViewModel`.
- `TodayViewModel` keeps the injected `ensureTaskRangeProvider` loader, which
  executes `EnsureTaskOccurrences` against `TaskRepository`. Existing repository
  changes and streak loading continue through the current composition boundary.
- A pure `BuildDailyOverview` calculation projects saved aggregates into the
  selected scope, agenda sections and summary. It has no Flutter, repository,
  service, SQL or localization dependencies.
- Existing task editor/action commands remain responsible for mutations and
  revision/conflict handling. Home never writes summary state or performs SQL.

**P01 (approved):** implement the overview as a pure domain calculation with
immutable domain input/output types, injected into the existing Today ViewModel.
Keep the current repository/service contracts, dependencies and database schema.
Add no extra asynchronous read use case: `EnsureTaskOccurrences` already owns
range materialization/loading; `BuildDailyOverview` owns the new derived rules.

This introduces no repository-to-repository dependency, second task store,
profile repository or new route. Views MUST NOT access repositories/services,
ViewModels MUST NOT depend on services, and use cases MUST NOT depend on services.

Feature-specific file changes are scoped to:

| File/location | Planned responsibility |
| --- | --- |
| `app/lib/domain/models/daily_overview.dart` | Immutable scope, section and summary types. |
| `app/lib/domain/models/task_ordering.dart` | Existing task comparator shared by repository and projection. |
| `app/lib/domain/use_cases/build_daily_overview.dart` | Pure daily eligibility, scope, grouping and summary calculation. |
| `app/lib/ui/dashboard/view_models/today_view_model.dart` | Snapshot state, loads, clock updates and retained filter intent. |
| `app/lib/app/dependencies/task_dependencies.dart` | Inject projection/clock, retain model and wire lifecycle cleanup. |
| `app/lib/ui/dashboard/views/dashboard_view.dart` and `widgets/` | Header, chips, summary, grouped agenda and availability states. |
| `app/lib/ui/dashboard/home_localizations.dart` and `app/lib/app/activity_monitor_app.dart` | Home strings and delegate registration. |
| `app/lib/ui/tasks/widgets/task_card.dart` | Opt-in notes preview with existing action behavior. |

## Data model changes

Persisted models remain unchanged: `TaskAggregate`, `TaskOccurrence`,
`TaskParticipant`, `TaskSchedule`, their identifiers and value objects already
supply effective date, completion, notes, companions, time windows and daily
period preference. Preserve these invariants rather than revalidating drafts.

Proposed immutable, nonpersisted overview types:

| Type | Fields and meaning |
| --- | --- |
| `DailyTaskScope` | Exactly one of All, Solo, Shared or a companion identified by its existing ID. A companion scope requires an ID; other scopes cannot carry one. |
| `DailyAgendaPeriod` | Morning, afternoon/evening, or any time; presentation localizes the labels. |
| `DailyAgendaSection` | Period and immutable ordered `TaskAggregate` list; count derives from that list. |
| `DailyProgress` | Total, completed, pending, collaborative occurrence count, fraction, integer percentage, optional next aggregate. |
| `DailyOverview` | Local day, effective scope, available real companions, filtered aggregates, nonempty sections and progress. |

Extend immutable `TodayState` to include its loaded local day/current clock
snapshot and optional overview, while retaining explicit loading/failure and
streak data. An absent overview means unavailable/not yet loaded; an available
empty overview represents a successful zero-result read. Views read derived
values from this snapshot rather than repeatedly filtering/calculating counts.

No schema migration or backfill is needed. No participant/profile records are
created for chips. Existing new-task IDs continue to use the injected UUIDv7
generator; existing IDs and persisted user data MUST remain unchanged. Any later
schema change requires a separately reviewed numbered migration, backup/data
migration and rollback strategy before implementation. Preserve the user's
existing `app/pubspec.lock` edits.

## Application contracts and deterministic calculations

**P02 (approved):** use the following concrete projection contracts. Extract the
existing `compareTaskAggregates` function from `LocalTaskRepository` into a
framework-independent domain utility and use it in both repository ordering and
overview ordering, preserving the function's existing behavior. Sort companion
chips by stored display name and then ID for deterministic ordering.

| Contract | Inputs | Output/failure behavior |
| --- | --- | --- |
| `BuildDailyOverview.execute` | `List<TaskAggregate> entries`, local `DateTime now`, requested `DailyTaskScope` | `DailyOverview`; pure synchronous projection over already validated data, with companion fallback to All. No storage failures or writes. |
| `TodayViewModel.load` | Current injected clock and existing requested scope | Existing asynchronous `TaskResult<List<TaskAggregate>>` load and streak result become available/loading/safe failure state. Ignore superseded or old-day results. |
| `TodayViewModel.setScope` | Typed scope from a rendered chip/reset action | Rebuild overview from loaded data without repository access or persistence. |
| `TodayViewModel.refreshForLocalDay` | Current injected clock on resume | Reload when the local day changes; otherwise refresh greeting/Next from the current successful snapshot and rearm the minute timer. |
| `TodayViewModel.refreshForClock` | Current injected clock at a minute boundary | Reproject existing data on the same day; invoke one current-day load when the loaded day differs. |
| Existing create/edit/action/Undo contracts | Existing task/occurrence IDs and expected revisions | Existing success, stale conflict, unavailable, busy and recovery behavior; refresh via committed repository changes. |

Projection order:

1. Retain nondeleted occurrences whose effective local date equals today's
   date. Preserve each distinct occurrence identity, including moved recurring
   instances that coexist on one day; never merge by title or task definition.
2. Derive companions from that entire daily set before applying the selected
   scope. Deduplicate companion identities by ID. Normalize an unavailable
   requested companion scope to All after a successful data load.
3. Apply exactly one approved scope. For a transient loading/error state, retain
   the requested scope; a failed read does not establish that a companion vanished.
4. Build morning, afternoon/evening, any-time sections in that order. A specific
   occurrence window determines the group using the 12:00 boundary. Otherwise,
   use a daily task's saved period preference; otherwise use any time. Apply the
   existing pending/time/title/occurrence-ID comparator within each group and
   omit empty sections. Do not change Calendar's flat ordering.
5. Compute counts/fraction/rounded percentage from that same filtered set.
   Collaborative count includes completed associated occurrences once each,
   regardless of companion count. Zero total gives fraction/percentage zero.
6. Select Next among pending timed occurrences whose start minute is at least
   the current local minute, ordered by start then the existing stable ties.
   Earlier-started tasks remain in their sections. A missing candidate is an
   explicit empty Next state; never substitute an untimed/overdue sample task.

## Session state, time and concurrency

**P03 (approved):** retain `todayViewModelProvider` for the application ProviderScope
lifetime instead of its current `autoDispose` lifecycle, so filters survive
Home↔Calendar navigation. Use one cancellable, one-shot timer aligned to the
next local minute; rearm from the injected clock after each tick/resume rather
than allowing periodic drift. Suspend the timer while the app is not resumed,
and dispose it with the model. Test time using Flutter's fake clock/timer tools
and the existing injected clock, without adding a scheduling package.

The timer updates the current clock snapshot, greeting and Next. Same-day ticks
MUST NOT load SQLite or recalculate persisted streak history. Day rollover,
manual retry and committed task changes use the existing asynchronous loaders.

Keep the current request sequence/disposed guards across both aggregate and
streak reads. Before publishing either result, also compare its captured local
day with the current injected local day. Reject old-day results and ensure a
current-day request; never flash yesterday's metrics under today's heading.
Use the latest requested scope when an in-flight load completes. Resume must
reproject the same day even when no date reload is necessary. These changes
must not reset Calendar's selected date or the shared action/Undo ViewModel.

## Presentation and patterns to follow

**P04 (approved):** keep `ui/dashboard/` and `DashboardView` as the existing Home
presentation location; add a `HomeLocalizations` delegate using the current
handwritten en-US/pt-BR localization pattern and register it alongside
`TaskLocalizations`. Extract small Home header, filter, summary and agenda
widgets under `ui/dashboard/widgets/`. Add an opt-in `showNotesPreview` argument,
default false, to the existing shared `TaskCard`; enable it only for Home.

- Match the supplied Today HTML/image hierarchy: contextual date/phrase and
  greeting, real scope chips, Rhythm summary, then editorial agenda sections.
  Preserve established tokens, forest filter states and current navigation.
- Use real neutral initials and the existing Profile/Calendar/notifications
  actions. Format dates/times through existing locale-aware formatters. Keep
  current safe unavailable notification feedback and no unread/presence dots.
- Summary includes completed/total, percentage inside or adjacent to a readable
  ring, localized pending/completion guidance, Next and collaborative count.
  Use wrapping/stacking layouts when compact or enlarged text needs more room.
- Companion chips show stored names and accessible identities; no remote avatar
  downloads or invented sample people. Keyboard users must reach every chip.
- Section headings use approved period labels and actual counts. Notes preview
  appears only for nonblank saved notes, uses two visual lines with ellipsis,
  and leaves full notes accessible through the existing Edit action. Preserve
  full task-title semantics, menu focus, swipes and pending action guards.
- Retain the shared Scaffold floating action, reserved scrolling space and
  application-scoped Undo banner above it. Successful creation defaults to
  local today; unavailable/loading guards and editor save failures remain intact.
- Use distinct loaded-empty and filtered-empty messages and reachable All/reset.
  Loading/unavailable content must not announce retained metrics as current.
- Compare fresh renders with both Stitch sources. Accessible 48px targets,
  supported routes and neutral identity are intentional deviations from export
  samples. Do not add focus timers, Insights, Tasks or new collaboration flows.

## Testing strategy and acceptance coverage

TDD MUST follow Red → Green → Refactor for each behavior: write a focused test,
run it and confirm the expected failure, introduce the minimum implementation,
then refactor after the test passes. Keep unrelated tests and existing Tasks
regressions passing; test behavior rather than copying implementation structure.

| Scope | Required verification | Acceptance |
| --- | --- | --- |
| Pure overview/domain tests | Due-today/deleted eligibility; scope exclusivity and missing-companion fallback; multiple companion deduplication; 4/7 → 57%; zero/all complete; noon and untimed-period grouping; stable ties; earliest eligible Next and minute-boundary exclusion. | AC-HOM-002–007, 013 |
| Today ViewModel tests | Scope retention during load/failure/navigation; successful fallback; no reads on filtering/same-day clock ticks; same-day resume; clock/day rollover; superseded aggregate/streak results; pause/rearm/dispose; safe failure/retry. | AC-HOM-001, 003, 006, 011–013 |
| Widget/localization tests | Greeting boundaries, locale dates and plurals; section counts; real/no fake companions; text progress semantics; reset action; optional two-line notes; keyboard focus and 48px controls at 320px/doubled text. | AC-HOM-001, 003–007, 013–014 |
| Integration with real SQLite | Create/edit/complete/reopen/postpone/delete/Undo followed by Home summary/group updates; restart persistence; failed-write safety; Home↔Calendar shared Undo and retained scope/Calendar date. Reuse file-backed test infrastructure. | AC-HOM-008–012 |
| Fresh visual/native checks | Both locales; 320px/doubled text, reference-matching compact and wide layouts; loading/empty/filtered-empty/unavailable/populated/complete; keyboard-visible editor and recovery feedback; comparison against HTML/image. | AC-HOM-014 |

Likely test locations: `test/home_overview_test.dart`,
`test/today_view_model_test.dart`, `test/home_view_test.dart`,
`test/home_localizations_test.dart`, `test/task_card_test.dart`,
`test/task_screen_state_test.dart`, and `test/task_workflow_integration_test.dart`.
Keep widget tests focused on presentation/interaction; use domain tests for the
projection math and real SQLite for durability. Prefer existing fakes at
boundaries, with no mocks for internal widget structure.

## Security and performance constraints

Task titles, notes, companion names and database values remain untrusted display
content. Never log private task content, expose technical errors or commit
secrets. This remains a device-local workflow: no account/authentication,
network service or remote authorization path is introduced. Future remote access
must default to denial and requires a separate specification.

Derive the overview once per successful load, scope change or clock update and
publish immutable lists. Process only today's loaded range; do not query all
historical/future tasks. Grouping/counts are linear after existing stable
sorting; sorting is bounded to the daily list. Reuse the existing batched streak
loader. Never run database work at every minute tick. Dispose subscriptions and
timers; filter selection and projection are read-only operations over the loaded
snapshot. Existing atomic writes, conflicts, migrations and recovery semantics
remain governed by Tasks and the SQLite ADR.

## Quality gates and delivery

Before feature completion, run `dart format .`, `flutter analyze`, and
`flutter test` from `app/`, then the debug Android build and fresh visual/native
checks. Record actual results and any diagnostics; do not use historical Tasks
results as Home acceptance evidence. The current SDK reports Material API
migration notices: retain them visibly if using `--no-fatal-infos` for the
analysis exit policy; errors/warnings remain fatal. Do not silently suppress
new diagnostics or migrate dependencies as part of this feature.

Use Dart MCP when available. Launch runtime debugging with `--print-dtd`; after
meaningful production edits hot reload a discoverable app, or hot restart for
initialization/state-lifetime changes. Keep all evidence in `.scratches/` and
synchronize acceptance results with the checklist after each verified item.

Check local computer time and branch conventions before any commit/push, and
preserve the user's existing lockfile changes. A future Home worktree/branch
must retain the completed Tasks baseline and approved Home documents.

## Reviewed plan decisions

H01–H07 are approved specification decisions; do not reopen them as unanswered
assumptions. P01–P04 are approved:

| ID | Proposal | Impact |
| --- | --- | --- |
| P01 | Pure domain overview, existing loaders/repositories, no schema/dependency change. | Medium |
| P02 | Typed projection contracts and shared domain comparator; deterministic companion order. | Medium |
| P03 | Retained Today ViewModel and lifecycle-aware minute timer without per-minute storage reads. | High |
| P04 | Existing dashboard location, dedicated Home localizations/widgets, opt-in shared-card notes preview. | Medium |

After approval, create `tasks.md` with ordered, verifiable Red/Green/Refactor
checklists, the required review checkpoint, and all H/P decisions with their
actual approval answers. Do not generate downstream placeholders beforehand.

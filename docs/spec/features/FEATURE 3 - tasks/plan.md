# SECTION 2: PLAN

## Review status and required context

The user approved [spec.md](spec.md), explicitly accepted all 24 spec
assumptions, and accepted plan decisions P01–P05. P05 was accepted after
clarification that Undo retains its remaining time across Today and Calendar
and uses elapsed time unaffected by device-clock changes. The user subsequently
approved this complete plan and requested [tasks.md](tasks.md). All decisions
and answers are recorded below and carried into that implementation checklist.

Implementation is complete in `feature/10-tasks-implementation`. Acceptance
evidence, rendered checks and tooling limitations are recorded in
[validation.md](validation.md); [tasks.md](tasks.md) records verified outcomes.

Before implementation, read:

- [constitution](../../project/constitution.md), always;
- [architecture](../../project/architecture.md) and
  [ADR 0001](../../../adr/0001-use-sqlite.md) for the structural/persistence work;
- [conventions](../../project/conventions.md) before changing production code;
- [design reference](../../project/design-reference.md), the two Stitch HTML
  exports and images linked by the spec, and `app/AGENTS.md` for UI work;
- the approved task spec and [calendar spec](../FEATURE%202%20-%20calendar/spec.md).

The spec is authoritative. If implementation requires a behavioral change,
revise the spec and obtain its approval before changing downstream documents.
Keep reviewed assumption answers when producing the later checklist.

## Architecture impact

### Current code and intended integration

The existing `CalendarRepository`/`CalendarDatabase` read the legacy entry
tables. `calendarViewModelProvider` captures one already-created future, so
calling `load()` again cannot obtain newly persisted data. `CalendarState`
owns selection/filter calculations. The Today dashboard and `ActivityCard`
currently contain presentation examples and nonfunctional actions.

Introduce task aggregates and use cases following the spec's default flow:

```text
TaskCard / TaskEditorSheet / Today / Calendar
                      ↓
TaskActionsViewModel / TaskEditorViewModel / screen ViewModels
                      ↓
SaveTask / EnsureTaskOccurrences / occurrence action use cases
                      ↓
TaskRepository (contract) → LocalTaskRepository → TaskDatabase
                                                    ↓
                                        initialized native SQLite database

CalendarViewModel → CalendarRepository → CalendarDatabase
                                         ↓
                           same canonical tables, read projection only
```

Use cases enforce task and schedule behavior and coordinate immutable mutation
plans; repositories commit them atomically. Simple reads, including editor
prefill, use ViewModel → Repository directly; no read use case is needed for
those single-source operations. `CalculateDailyStreak` is a pure domain
operation over repository-supplied history.

Repositories MUST NOT depend on each other. CalendarRepository does not call
TaskRepository; CalendarViewModel calls `EnsureTaskOccurrences` before its
calendar projection read. Views MUST NOT access repositories/services;
ViewModels and use cases MUST NOT depend on services. No SQLite or Flutter
types enter domain models, value objects, use cases, or result contracts.

### Feature organization and composition

**P01 — Approved decision:** Implement the following concrete organization using the
existing dependencies and handwritten immutable state classes. Add no package,
ORM, generated-model requirement, or persistent database worker for this
feature.

| Location under `app/lib/` | Responsibility |
| --- | --- |
| `domain/models/task.dart`, `task_occurrence.dart`, `task_subtask.dart`, `task_schedule.dart`, `task_result.dart` | Immutable aggregates, schedule snapshots, typed results and validation failures. |
| `domain/value_objects/` | IDs, bounded text/tag names, local dates/ranges, time windows, weekly days, reminder preferences. |
| `domain/use_cases/` | Save, recurrence generation/reconciliation, completion/reopen, postpone, delete/Undo, streak calculation. |
| `data/repositories/task_repository.dart` | Domain-oriented abstract repository contract. |
| `data/repositories/local_task_repository.dart` | Domain/row mapping, conditional commits, failure translation, committed change stream. |
| `data/services/task_database.dart` | Async adapter to isolated reads/writes using persistence DTOs. |
| `data/services/database/task_database_operations.dart` | Connection-scoped SQL, row DTOs, write transactions and conditional checks. |
| `data/services/database/migrations/migration_0004_create_task_tables.dart` | New schema and legacy transformation. |
| `ui/tasks/view_models/` | Editor draft/state, action state and Undo lifetime. |
| `ui/tasks/views/task_editor_sheet.dart` | Compact sheet/wide dialog and guarded dismissal. |
| `ui/tasks/widgets/` | Shared TaskCard, swipe wrapper, actions menu, checklist, schedule controls, recovery banner. |
| `ui/tasks/task_localizations.dart` | Feature-owned strings, plural messages and validation-code translation. |
| `ui/dashboard/view_models/today_view_model.dart` | Durable Today agenda, filters, counts and daily progress. |
| `ui/calendar/` | Existing navigation/filter state and canonical agenda integration. |
| `app/dependencies/task_dependencies.dart` | Clock, repository, use cases, stable screen models and subscriptions, wired from the app composition boundary. |

Reuse `databaseInitializationProvider` for the database path and startup errors,
`uuidProvider` through an injected `String Function()` calling UUIDv7, existing
Riverpod composition, `ApplicationShell`, `ScreenTitleBar`, `ActivityTheme`,
`ActivityColors`, and `ActivitySpace`. Keep task-specific UI in `ui/tasks/`;
only general shared theme/localization wiring belongs outside it.

### Repository refresh and screen state

LocalTaskRepository owns `Stream<TaskChange>` and emits after successful commits
that actually change persisted data. Events contain task IDs, affected original
and effective dates, and whether shared metadata changed; they contain no task
content. Calendar and Today subscribe through injected screen-model dependencies.
Both query canonical data again instead of keeping independently writable copies.

Replace the captured calendar future with a fresh range-loader callback. Keep
the CalendarViewModel instance stable across refreshes and replace its immutable
data/loading/error state while retaining selection, mode, cadence filter, and
participant filter. A request sequence prevents an older async result from
overwriting a newer date-range request. Unsubscribe on disposal. Do not recreate
the screen model merely because a data provider was invalidated.

Load/ensure the actual interval represented by `CalendarState.visibleDays`,
including adjacent-month cells, before computing indicators. A month/week/date
change requests the new interval. Always load the available participant filter
catalog independently of the current range so selection does not disappear on
an empty day. Shared cards obtain task/occurrence details from the same range
snapshot; they do not issue a query per card.

Today ensures and reads the current local day, replaces the fixed sample cards,
and derives counts/progress from its visible occurrences. Implement the existing
All/Solo/Shared controls as participant-presence filters. On resume or a local
date boundary, recompute Today and any current-day defaults using the injected
clock; do not reset an explicitly selected Calendar date. Empty/unavailable
states expose no fabricated counts. Refresh failures show unavailable status
and disable affected actions until a successful reload.

Materialization emits only when it inserted rows. Ensuring an already-loaded
range is a no-op, preventing refresh/generation notification loops. A mutation
may commit even if the following read fails: announce the committed action and
show the refresh failure separately; never replay it automatically as an
uncommitted write.

## Data model changes

### Domain invariants and normalization

Use the table/field proposal in the approved spec, including separate task
definitions, occurrence identities, task tags, participant links, active subtask
definitions, and occurrence-specific checklist state.

`TaskId`, `OccurrenceId`, `SubtaskId`, and `TagId` wrap stable strings. New entity
IDs are generated through the injected UUIDv7 dependency; do not reject or
rewrite valid existing IDs merely because they are not UUIDv7. Preallocate IDs
once per new draft entity so retrying a failed save does not create a new
identity. No UI code generates entity IDs on each rebuild.

**P02 — Approved decision:** Count bounded text in Unicode scalar values (`runes.length`),
not UTF-16 code units or grapheme clusters. Trim title, subtask, and tag values
with the shared domain normalizer. Tag input may include one leading display
`#`, which is removed before normalization; its key is the remaining trimmed
name lowercased with Dart's locale-independent `toLowerCase()`. Preserve display
casing and do not introduce Unicode canonical normalization or accent folding.
Reject embedded NUL in bounded text because its storage length semantics would
differ. Preserve notes' internal whitespace and line breaks.

Domain factories own semantic validation and return field-path/error-code
failures. UI enablement and inline messages use those results. SQL constraints
provide additional integrity guarantees; they are not a second business-rule
engine. SQL length checks use the same scalar-count limits. Store the domain's
normalized tag key; do not use SQLite `lower()` or collation as a substitute.
Hydration validates existing titles without rewriting their stored text;
trimming applies to explicitly saved drafts. Migration and read mapping must
not silently normalize preserved legacy titles.

`LocalDate` stores year/month/day and validates a real calendar date before
serialization. Calendar arithmetic uses UTC date-only construction as an
internal counting representation, then produces `LocalDate`; it never converts
a scheduled date from a UTC instant to local time or adds 24 elapsed hours to
a device-local timestamp. Windows store minutes 0–1439 with end > start. Store
completion/deletion/update instants as UTC ISO-8601 text. Format them only in UI.

`TaskSchedule` includes cadence, explicit repeat enablement, start date, selected
weekdays and effective boundary. `WeeklyDays` is nonempty for an enabled weekly
rule. Clearing a time window clears its reminder. Changing away from daily
clears daily-only settings; changing away from weekly clears current weekdays.
Draft switching can retain temporary field values, but the saved aggregate
must satisfy these invariants.

### Schema constraints and ownership

Create the spec's tables in migration 0004 and retain `calendar_participants`.
Add nonnegative revision checks, enum/boolean checks, text/date shape checks,
paired window checks, allowed reminder offsets, and pending-completion checks.
SQL nullable checks MUST explicitly require either both window fields null or
both non-null and valid; a half-null pair must not pass through SQL's null
truth rules. Completion time may be null for a legacy completed occurrence;
all newly completed occurrences receive the injected clock instant.

Use these supporting keys/indexes:

- Unique (`task_id`, `scheduled_date`) on occurrences, including tombstones.
- Unique (`task_id`, `id`) on occurrences and subtask definitions to support
  ownership-preserving composite foreign keys in occurrence-subtask state.
- Partial unique (`task_id`, `position`) for active subtask definitions.
  Reordering temporarily deactivates affected definitions within the save
  transaction, assigns final positions, and reactivates them without deleting
  their completion state.
- Index (`effective_date`, `completed`, `id`) for visible occurrences, excluding
  tombstones; unique original-date index for slot lookup/streaks; indexes on
  (`participant_id`, `task_id`), tag links, and child ownership keys.
- Child foreign keys and cascades as specified. Definition removal marks a
  subtask inactive; Delete marks an occurrence tombstoned. No purge job runs.

Checklist and selected-tag count limits are aggregate invariants enforced under
the write transaction with expected task revision, rather than independent
ViewModel validation. Reuse an existing normalized tag under its unique key;
concurrent equivalent tag creation resolves to that same tag ID.

### Preserving schedule history during lazy generation

An overwritten current rule alone cannot reconstruct an unvisited past interval
after a recurring task is edited. Eagerly generating its entire lifetime would
conflict with bounded, on-demand loading. Retain historical scheduling inputs
as part of the same task aggregate.

**P03 — Approved decision:** Extend the proposed schema with `task_schedule_history`, a
task-owned archive of scheduling snapshots, so the approved past-preservation
behavior also holds for dates that were never materialized before an edit.
This is persistence for the existing recurrence requirement, with no additional
user-facing workflow.

`task_schedule_history` has composite primary key (`task_id`, `effective_from`),
FK `task_id` → tasks with cascade, `effective_until` exclusive, `start_date`,
`cadence`, `recurrence_enabled`, `weekday_mask`, paired `start_minute`/`end_minute`,
and `reminder_minutes_before`. It uses the current-rule enum, date-shape,
boolean, window and reminder checks; `effective_until > effective_from`;
`weekday_mask` is 0–127 and is nonzero only for enabled weekly rules. Domain
`WeeklyDays` maps Monday to bit 0 through Sunday to bit 6. It stores old
scheduled defaults, not task titles, notes, tags, or editable history UI.

The task's current schedule fields and `task_weekdays` represent its newest
rule, effective from `rule_effective_date` (initially the start date). Historical
rows cover earlier half-open periods and never overlap. A schedule edit closes
the previous active period at tomorrow and replaces the pending current rule.
Repeated edits before the same tomorrow boundary replace that pending rule
without creating zero-length/overlapping history. A task whose first start is
still in the future does not need a fabricated historical period.

The domain mutation plan validates period boundaries; the repository verifies
the expected task revision and writes history/current rule atomically. Range
generation selects the applicable snapshot for each original scheduled date.
Disabled legacy schedules produce no new slots. A change to one-time stops new
generation from its effective boundary and preserves protected stored slots;
the selected occurrence remains the explicitly saved one-time instance.

Streak calculation uses the active daily segment's start, derived from these
periods, and the original-date completion records. Turning streak visibility
off does not end a daily schedule segment or erase its completions. Switching
away from daily and later returning begins a new daily segment. Future-dated
rules cannot contribute to today's streak.

### Recurrence and mutation algorithm

1. `EnsureTaskOccurrences(range)` obtains relevant current/historical schedule
   snapshots and task revisions. Pure domain expansion produces matching
   original dates only within the requested interval and on/after each start.
2. Supply candidate IDs and default effective windows/reminders to the
   repository. Under `BEGIN IMMEDIATE`, verify schedule revisions and insert
   only absent slots using a conflict target limited to the unique slot key.
   Do not ignore unrelated constraint failures. Existing moved/completed/
   deleted slots retain their original identities and state.
3. Commit a range snapshot or reload it after the commit. Effective-date reads
   also include previously moved-in occurrences whose original slots lie
   outside the requested interval. Emit a change only when data changed.
4. A schedule edit updates task metadata/checklist/tag changes, archives the
   old rule, reconciles untouched future slots, and applies the selected
   occurrence exception in one transaction. Keep slots through today and all
   completed, tombstoned, or explicitly modified exceptions. Regenerate only
   requested ranges; retain history for future visits to other ranges.
5. When old/new rules match the same untouched slot, update its defaults in
   place and retain its ID. Delete only untouched pending future slots that
   cease to match. The selected instance and any user-modified checklist state
   are protected from such reconciliation as explicit exceptions.

Generate no infinite date series. A schedule-revision race retries expansion
once from a fresh snapshot; a repeated race returns a retryable conflict.
The write transaction contains only precomputed changes and integrity checks,
never domain callbacks, clocks, UI waits, or external operations.

Task revision increments when shared metadata, definitions, tags, or scheduling
change. Occurrence revision increments for completion, effective scheduling,
checklist-state changes, deletion, and Undo. Generation does not increment the
task revision, but it MUST verify it before committing. This permits independent
occurrence actions without making every series card stale while protecting
edits/Undo from shared-content changes.

Treat a user-edited occurrence, including checklist changes and reopening a
previously completed future slot, as an explicit exception for reconciliation.
The mutation's previous exception flag is part of its Undo snapshot. A later
rule edit must not discard intentional pending work merely because its parent
is currently incomplete.

### Migration and rollback

Add `migration_0004_create_task_tables.dart` /
`Migration0004CreateTaskTables`, identifier `0004_create_task_tables`, to
`migrations.dart` after 0003. If another migration arrives first, follow S23.
Do not change applied migration bodies or persistent identifiers.

Within the initializer's existing migration transaction:

1. Create the new tables, ownership keys and indexes.
2. Validate each legacy row using migration-compatible domain normalization.
   Preserve legacy title bytes and IDs; do not silently trim, truncate, or
   discard records. If a row cannot satisfy the new required invariants,
   abort safely instead of partially converting it.
3. Insert one task and occurrence per entry, retaining its ID in both separate
   tables, title/date/cadence/completed state, and nullable unknown provenance.
   Set low priority, recurrence off, no time/reminder/checklist/tags, revision
   zero, no historical schedule rows, and no invented completion timestamp.
4. Copy participant links to task ownership without changing participant IDs
   or names. Compare old/new row counts, field values, and association sets;
   run foreign-key integrity checks before dropping old entry/link tables.
5. Drop the old link table before its parent entry table. Keep participant,
   migrations, and other unrelated tables. The initializer records the new
   history/version only as part of successful completion.

Switch CalendarDatabase SQL to canonical joins in the same release. Updating
its read contract to accept a date range must not change calendar filtering or
selection semantics. Do not leave a writable legacy shadow store.

Fresh installs continue through migrations 0001–0003 and their once-only seeder
before 0004 transforms those examples. Version-1 reconciliation remains the
initializer's responsibility. Upgrade must not rerun a completed seeder or
automatically enable repeats for its examples.

Test transactional rollback at table creation, record/link copying, integrity
checks, and after removal of old tables. On failure, schema, data and history
must remain at their pre-upgrade state. Reject newer/inconsistent versions.
Never recover by deleting/recreating the database.

Successful downgrade is not automatic: the old schema cannot represent the new
data. Operational rollback stops the app and restores a pre-upgrade backup
with the matching application version, retaining/exporting subsequent data
before a deliberate conversion. Document this in `app/README.md`; the feature
does not silently create or restore a backup on startup.

## Application contracts

### Shared types and failure handling

Use `Future<TaskResult<T>>` for asynchronous domain-facing operations.
`TaskResult<T>` distinguishes success from typed `TaskFailure` values:
`validation(fields)`, `notFound`, `deleted`, `staleRevision`, `invalidTransition`,
`undoExpired`, `undoReplaced`, and `storageUnavailable`. Domain validation codes
are translated to localized field messages at the presentation boundary.
Unexpected infrastructure errors retain sanitized diagnostic context at the
repository boundary and become `storageUnavailable`, not empty results.

`ExpectedTaskRevision` and `ExpectedOccurrenceRevision` accompany edits.
`TaskMutationReceipt` contains identities, committed revisions, affected dates,
whether a change occurred, and an optional Undo snapshot. A no-op does not emit
a change or replace an existing Undo token with a misleading new one.

### Use cases

| Contract | Inputs → success | Expected failures/behavior |
| --- | --- | --- |
| `SaveTask.execute(draft, target?, expectedRevisions?)` | Raw draft values and optional existing task/occurrence → receipt plus saved aggregate. Allocate IDs once, validate, prepare shared/instance changes, commit atomically. | Validation, missing/deleted target, stale revision, unavailable storage. New drafts keep their allocated IDs across retries; edits never fall back to create. |
| `EnsureTaskOccurrences.execute(range)` | `LocalDateRange` → materialized interval/read snapshot. | Invalid range, repeated stale schedule, unavailable storage. Slot collision means existing occurrence, not duplicate creation. |
| `CompleteTaskOccurrence.execute(id, expected)` | Occurrence identity/revisions and injected instant → done receipt with previous state for Undo. | Missing/deleted/stale/unavailable; already completed is idempotent and does not replace its completion time. |
| `ReopenTaskOccurrence.execute(id, expected)` | Identity/revisions → pending receipt with null completion time. | Missing/deleted/stale/unavailable; already pending is a no-op. Does not alter subtasks. |
| `PostponeTaskOccurrence.execute(id, expected)` | Pending occurrence, injected local today → tomorrow's effective date with original slot/window duration preserved. | Completed/missing/deleted/stale/unavailable; already due tomorrow is an informational no-op. |
| `DeleteTaskOccurrence.execute(id, expected)` | Identity/revisions → persisted tombstone and recoverable previous state. | Missing/stale/unavailable; no series deletion or physical purge. |
| `UndoTaskOccurrenceAction.execute(token)` | Current unexpired action token and expected revisions → restored occurrence receipt. | Expired/replaced/stale/missing/unavailable; conditional restore cannot overwrite a later change. |
| `CalculateDailyStreak.execute(scheduleHistory, completions, today)` | Domain history only → applicable nonnegative count or not-applicable result. | Disabled/non-daily is not applicable; failure to load history is handled before this pure operation, never converted to zero. |

Overlaps are a separate advisory result from schedule validation. Before
checking an edited effective date, ensure the competing schedules on that
date, read their windows, and exclude the target occurrence. Debounce advisory
reads and ignore stale responses. Recheck at submission; overlap never causes
a valid transactional save to fail or promises that future dates are clear.

### Repository and service operations

| TaskRepository operation | Contract |
| --- | --- |
| `loadTask(taskId, occurrenceId)` | Return aggregate, selected occurrence/checklist and revisions for editing, or explicit unavailable/not-found/deleted result. |
| `loadRange(range)` | Return committed visible cards, shared metadata, checklist summaries, participant names and revisions; excludes tombstones. |
| `loadScheduleSnapshot(range)` | Return relevant current/history rules and revisions without materializing or mutating them. |
| `loadStreakHistory(taskIds, throughDate)` | Return original-date completion sets and relevant daily schedule periods, in a batched read; include deletion status so deleted dates do not contribute. |
| `saveTask(preparedChange, expected)` | One transaction for definitions, normalized tags, selected occurrence/checklist, current/history rules and future reconciliation. |
| `ensureOccurrences(candidates, expectedTaskRevisions)` | Verify revisions, insert missing slots and return changed dates; preserve unique slots and existing exceptions. |
| `applyOccurrenceChange(preparedChange, expected)` | Conditionally commit one occurrence action and its receipt, checking both task and occurrence state. |
| `restoreOccurrence(undoSnapshot, expected)` | Conditionally restore the prior occurrence fields without recreating entities or rewriting shared task content. |
| `changes` | Post-commit `Stream<TaskChange>` owned/disposed by the repository composition scope. |

`CalendarRepository.load(range)` returns its existing domain calendar projection
extended with task/occurrence identities and the detail needed to reuse shared
cards. Keep cadence/participant filter behavior and read-only ownership.
CalendarRepository and TaskRepository may use the same lower-level SQL query
helpers/services but must never call one another.

TaskDatabase operations mirror row reads and prepared writes: read aggregate,
range, schedules, streak rows; commit aggregate; insert slots; update occurrence;
restore occurrence. DTOs contain serializable values and expected revisions.
SQLite connections, statements, exceptions, and SQL strings do not cross into
ViewModels or domain operations. Every write transaction verifies affected-row
counts and rolls back if its compare-and-set predicates fail.

Use the existing isolate-per-operation approach: pass the initialized path and
serializable request to `compute`, open the connection in the worker, enable
foreign keys, execute the whole operation, and close it in `finally`. Return
sanitized row/write results to the repository for mapping and notification.
Reads requiring multiple related queries use one read transaction for a
consistent snapshot. SQLite serializes competing write transactions; revision
checks protect changes prepared against older snapshots. No isolate is given a
live database handle, ViewModel, repository, or UI callback.

## Patterns to follow and presentation design

### Editor and localization

TaskEditorViewModel exposes one immutable `TaskEditorState` containing loaded
identity/revisions, draft, validation result, overlap advisory, dirty status,
and load/save state. A new task starts from S03 defaults and its launch date;
a saved task loads all fields and distinguishes shared-series defaults from
the selected occurrence's effective window/date.

Show explicit scope guidance beside recurrence and effective-date controls:
shared metadata/checklist changes apply to the task, schedule changes apply
from tomorrow, and the occurrence date/window is an exception. Expose separate
labeled defaults and occurrence overrides when editing a recurring task so
one control does not silently perform both operations. Legacy repeating-cadence
labels show the explicit enable-repeat control required by S14.

Preserve Task Details → Scheduling & Cadence → Subtasks order. Use a scrollable
body and persistent primary/cancel footer. Guard barrier taps, close, Back/
Escape and handle drags through one dismissal request. Native uncontrolled
barrier/drag dismissal must not bypass dirty-draft confirmation or saving locks.
Use `PopScope` plus controlled sheet dismissal. On failure retain the full
draft; after success close and restore focus to the launcher or a stable list
heading if the launching card was removed.

**P04 — Approved decision:** Switch from bottom sheet to bounded dialog at 600 logical
pixels of available width; cap the dialog at 560 logical pixels and at the
available safe height. Use a dedicated `TaskLocalizations` delegate with en-US
and pt-BR strings and plural methods, added alongside the existing Material
delegates. Use Material localizations for date/time formatting; no new
localization dependency is needed.

Use existing project tokens with local card/input styles satisfying the spec's
design interpretation. The current shared CardTheme radius is 24; do not change
the global theme to make task cards match. Override task-card geometry within
the project reference's 8–16 range. Preserve serif titles, calm neutral
surfaces, restrained cadence/priority pills, and visible focus/48-pixel targets.

### Cards, gestures, and Undo

Replace the calendar's simple agenda tiles and Today examples with `TaskCard`.
Views receive presentation data and commands; no card reads the database.
Streaks and subtask counts come from domain/repository data, not card arithmetic
that duplicates business calculations. An unknown completion time shows a
generic completed label. Reminder labels state that notifications are inactive.

Implement a horizontal-drag wrapper with an absolute 90-logical-pixel threshold;
default fractional dismissal thresholds are insufficient. Commit on release
only, including at exactly 90, with no fling-velocity shortcut. Cancel and
below-threshold release animate back; vertical gestures continue to scroll.
Checkbox/menu interaction does not also trigger the card drag. Right swipe on
done is a no-op. During an action disable that occurrence's controls; remove or
restyle it after persistence succeeds. Failure returns it to rest with a safe
error. Reduced motion skips unnecessary movement while keeping outcomes and
explicit controls identical.

**P05 — Approved decision:** Keep one application-scoped TaskActionsViewModel for the latest
Undo token/banner so navigation between Today and Calendar does not reset its
remaining recovery window. Use an injected monotonic elapsed timer, separate
from the wall clock used for stored instants.

For example, deleting a task on Today and switching to Calendar two seconds
later leaves roughly three active seconds to Undo. Switching screens does not
restart or dismiss the countdown. Changing the device clock does not shorten
or extend it. Focus pauses and accessible timeout extensions still apply.
Restarting the app ends the window as already agreed in S20.

After successful completion or deletion show the latest recovery banner for
five active seconds. The token holds the previous occurrence state and the
resulting task/occurrence revisions; an action sequence makes old replaced
tokens unusable. Pause timing for keyboard/accessibility focus and honor
accessible timeout extensions; keep Undo reachable above navigation/keyboard.
While Undo is writing, disable it and suspend expiry; a write failure retains
the token until its remaining active duration expires. Successful restoration
clears the token and emits the normal committed change. Disposal/restart ends
the in-memory token only; tombstones remain durable.

## Testing strategy

Every behavior follows mandatory Red-Green-Refactor: write the smallest
observable failing test, confirm failure for the expected reason, implement
only enough to pass, then refactor without changing behavior. Prefer repository
fakes for ViewModels; mock only architectural boundaries where an interaction
assertion is necessary. Each test has one primary behavior and binary assertions.

### Domain and use-case tests

- Scalar text limits, Unicode/emoji boundaries, NUL rejection, tag normalization
  and equivalent-name reuse; local-date validity, weekly-day requirements,
  window/reminder validity, and default-clearing on cadence changes.
- Daily/weekly expansion from lower-bound starts, leap/month/year/DST dates,
  disabled legacy recurrence and no duplicate original slots.
- Schedule changes before/after an effective boundary, repeated same-day edits,
  old unmaterialized ranges, stopped/restarted daily segments, protected future
  exceptions and untouched-slot identity retention.
- Streaks ending today/yesterday, gaps, deletion/reopen/Undo, postponed backfill,
  future exclusion, disabled visibility, and inaccessible-history errors.
- Parent/subtask independence, new definitions/occurrences pending, identity
  retention on rename/reorder, and inactive-definition exclusion.
- Tomorrow arithmetic, coexisting postponed/normal occurrences, no-op actions,
  overlap exclusion/adjacency and advisory-only behavior.

### Real SQLite, migration, and repository tests

Use real SQLite for persistence guarantees, with in-memory connections for
constraints/mapping and file-backed connections for restart/concurrency/isolate
behavior. Put project working artifacts under `.scratches/`; clean up only
test-owned files. Inject deterministic dates/UUIDs; use no sleep-based timing.

- Test fresh initialization, version 1 without migration history, version 2,
  and current version 3 upgrades. Assert IDs, every migrated value, associations,
  completion/provenance nullability, examples, and unchanged old history names.
- Exercise enum/boolean/text/window/reminder constraints, duplicate slots/tags,
  invalid foreign keys and cross-task subtask state, unique active positions,
  legacy done/unknown time, and schema/history rollback at each migration stage.
- Force a failure after parent/tag/subtask changes and prove atomic rollback;
  prove stale compare-and-set writes change nothing and emit no success event.
- Race materialization against materialization and schedule edits through
  separate connections; verify one slot per date and no old-rule commit.
- Persist deletion, reopen the database, and ensure its original range again;
  assert the tombstoned slot is not resurrected. Test valid/stale Undo and
  preservation of checklist, links, effective schedule and original identity.
- Confirm post-commit notification/no-op behavior, batched range projections,
  real calendar joins and moved-in instances. Close all owned connections.

Existing calendar database/completion/seeder tests insert into old tables and
assert version 3. Preserve tests of historical migrations by explicitly
applying their historical migration list; update latest-schema fixtures and
assertions to canonical tasks/occurrences. Do not weaken preservation or
startup-failure assertions to accommodate a breaking reader.

### ViewModel, widget, and integration tests

| Acceptance coverage | Verification |
| --- | --- |
| AC-TSK-001–007 | Launch-date/default forms, durable round trip, prefill, dirty dismissal choices, field validation, clearing window/reminder. |
| AC-TSK-008–011 | Advisory overlap/self-exclusion/adjacency, saving locks on every dismissal path, atomic failure with draft retention and retry. |
| AC-TSK-012–020 | Domain and real-database recurrence, schedule history, streaks, checklist identity/independence and calendar arithmetic. |
| AC-TSK-021–028 | Checkbox/menu/swipe equivalence, exact 89/90-pixel boundary, drag cancellation/vertical scroll, reopening, postpone, deletion, Undo and stale recovery. |
| AC-TSK-029 | Live Today/Calendar refresh of cards/counts/indicators and streaks with selection/filter preservation; drop stale range responses. |
| AC-TSK-030–032 | Upgrade/rollback, no automatic repeats for examples, empty/unavailable distinction and absence of sample counts. |
| AC-TSK-033–035 | en-US/pt-BR, keyboard/screen-reader semantics, focus return, reduced motion, large text/keyboard/safe-area layout, all card/modal states and reference comparison. |

Widget tests cover presentation and interactions with repository fakes; do not
repeat database or streak business logic in widget assertions. Use fake elapsed
time for Undo replacement, expiry, focus pauses, write-in-flight behavior and
navigation; cover accessible timeout extension explicitly. Integration tests
use file-backed persistence across repository recreation and the shared
composition to verify committed changes reach both screens.

Capture manual screenshots at the reference viewports and compare them with
both Stitch exports, including modal sections initially outside the visible
scroll area. Also verify narrow/wide layouts and enlarged text. Save captures
under `.scratches/` and report any mismatch or inability to perform visual
verification. No Flutter hot reload is required for documentation-only work;
implementation follows `app/AGENTS.md` runtime inspection guidance.

### Quality gates and completion

From `app/`, run and pass:

```text
dart format .
flutter analyze
flutter test
```

The implementation is complete only when all 26 requirements and 35 acceptance
criteria are satisfied, existing regressions remain covered, visual validation
is recorded, feature/project documentation is synchronized, and no known
constitution violation remains. The later `tasks.md` must contain ordered,
independently verifiable Red-Green-Refactor checklists and the required manual
review checkpoint, carrying every assumption and its actual reviewed answer.

## Security and performance constraints

This is the approved single-device, offline scope: no new authenticated or
remote operation is introduced. Existing local participant links are context,
not authority to access a remote user's data. Any later remote permission
decision must default to denial; this feature provides no implied authorization
or synchronization promise. Reminder preferences never request notification
permissions or invoke platform delivery.

Treat draft and persisted data as untrusted. Parameterize all SQL. Log only
operation/category, sanitized error type, and non-content technical context;
exclude titles, notes, tags, participant names, raw SQL values and potentially
sensitive exception text. Keep secrets out of source and artifacts. Expected
conflicts are typed outcomes; unexpected failures remain observable without
exposing task content.

Native storage retains the existing application-support location and migration
lifecycle. SQLite constraints, conditional transactions, durable tombstones and
history provide integrity; no storage encryption, web-storage implementation,
or remote backup is added. Unsupported storage shows unavailable rather than
reporting ephemeral in-memory success.

Bound materialization to requested intervals. Batch card metadata, checklist
and streak queries by IDs/ranges. Query streak completions using indexed
original dates; stop the domain scan at the first gap instead of enumerating
all uncompleted historical days. Use schedule history instead of eagerly
materializing years of past dates on a rule edit. Keep writes short, move SQL
off the UI isolate, and avoid per-card queries. No numeric latency target is
specified; report measured UI stalls rather than inventing a performance SLA.

## Assumption decisions

The user explicitly accepted every spec assumption and all five plan
assumptions, including P05 after its cross-screen Undo behavior was clarified.
S01–S24 below preserve the reviewed spec statements in source order with their
accepted answers. No assumptions remain pending. The user subsequently approved
the complete plan and requested the implementation checklist.

**S01 (spec)**

Assumption: creation is available from Today and Calendar; Calendar creation defaults to its selected date, and Today creation defaults to the current local date. Today lists occurrences due today and derives its task counts/progress from those occurrences. Existing dashboard section labels may adapt to actual data; unrelated navigation and focus-session features remain unchanged.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S02 (spec)**

Assumption: task creation is personal and local to one device. Existing participant associations remain visible and survive edits, but this editor has no participant assignment, invitations, synchronization, or authentication. Task details, focus timers, a separate archive, arbitrary custom recurrence, and notification delivery are outside this feature. Custom cadence is visibly unavailable rather than selectable without functioning behavior.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S03 (spec)**

Assumption: defaults are low priority, one-time cadence, no tags or subtasks, no time window, no reminder, and streak tracking off.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S04 (spec)**

Assumption: titles are trimmed and limited to 200 characters; notes to 10,000 characters; tags to 32 characters and ten selected tags per task. Tag identity uses trimmed, case-insensitive names without a leading display `#`; original display casing is preserved.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S05 (spec)**

Assumption: windows are within one local calendar day; overnight windows are rejected with field guidance. Past dates are permitted.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S06 (spec)**

Assumption: options are Off, At start, 5, 15, 30, or 60 minutes before, defaulting to Off; the reference's Calm Chime is a future delivery treatment, not a sound selector.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S07 (spec)**

Assumption: daily means every calendar day; weekly means every week on the selected weekdays; new weekly tasks initially select the scheduled date's weekday. Day-period preferences are labels and do not infer a time window. The chosen start date is a lower bound: a weekly task's first occurrence is its first selected weekday on or after that date. New daily/weekly tasks enable recurrence on save.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S08 (spec)**

Assumption: title, notes, tags, priority, reminder/time defaults, and subtask definitions belong to the recurring task and are shared across its cards, including historical cards. Recurrence changes take effect from tomorrow, preserving past and today's occurrences, completed occurrences, and explicitly moved/deleted occurrences. The selected occurrence's date/time can be edited as an exception without moving the series. A one-time task's date/time edit moves its only occurrence.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S09 (spec)**

Assumption: up to 50 subtasks, each with a trimmed nonblank title of at most 200 characters; new recurring occurrences start with all subtasks pending. Accessible move-up/down actions accompany drag ordering.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S10 (spec)**

Assumption: parent and subtask completion are independent; completing all subtasks does not automatically complete the parent, and completing or reopening a parent does not change its subtasks.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S11 (spec)**

Assumption: an occurrence already due tomorrow produces an informational no-op. A moved recurring occurrence may coexist with tomorrow's normal occurrence; they remain distinct and MUST NOT be merged.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S12 (spec)**

Assumption: deletion removes only one occurrence, never the series; completed is not a separate archived lifecycle. Completion Undo also lasts five seconds. Only the latest undoable action has an active banner; replacing it ends the previous window. Windows pause while the banner has keyboard or assistive-technology focus and respect accessible timeout extensions.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S13 (spec)**

Assumption: before saving, close, backdrop, Back/Escape, and sheet dragging discard a clean draft immediately; dirty drafts require Keep editing or Discard changes.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S14 (spec)**

Assumption: each legacy calendar entry becomes an independent task with one stored occurrence; its cadence label is preserved, but automatic recurrence stays disabled until the user explicitly enables it in the editor. Existing example entries remain identifiable as examples and MUST NOT expand automatically. A legacy non-repeating daily/weekly task shows explanatory guidance and an explicit Enable repeating schedule control; opening and saving unrelated details does not implicitly enable it.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S15 (spec)**

Assumption: travelling leaves scheduled wall dates/times unchanged; no time-zone identifier or cross-device scheduling is introduced.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S16 (spec)**

Assumption: a streak is consecutive original scheduled local dates completed for one enabled daily task. If today's occurrence is pending, the run ends yesterday; if it is completed, it ends today. Missing, pending, or deleted earlier dates break the run; future dates are excluded. A postponed occurrence counts for its original date when eventually completed, allowing intentional backfill. No completion before the daily schedule's effective start contributes.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S17 (spec)**

Assumption: deleting a definition removes it from all displayed checklists but retains historical state internally; unchanged definitions retain completion, and added definitions start pending.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S18 (spec)**

Assumption: the advisory checks the selected occurrence's effective date, not every future repeat.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S19 (spec)**

Assumption: pending cards precede completed cards; within each group timed occurrences sort by start time, untimed occurrences last, then title and identity.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S20 (spec)**

Assumption: restarting closes outstanding Undo windows; committed deletion remains effective. Recovery of an entire recurring series is not needed because deleting a series is not exposed in this feature.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S21 (spec)**

Assumption: the following feature-specific components implement the requested behavior using existing Riverpod composition, the injected UUID generator, database initialization, localization, and shared theme. No new package is required by this proposal.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S22 (spec)**

Assumption: use `tasks` as recurring definitions and `task_occurrences` as materialized dated instances. Normalize tags, weekdays, and checklist state as below; reuse `calendar_participants` to preserve existing participant identity. This replaces the legacy writable entry tables instead of maintaining two competing task stores.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S23 (spec)**

Assumption: the next migration is `migration_0004_create_task_tables.dart` / `Migration0004CreateTaskTables`, registered as `0004_create_task_tables`. If another migration lands first, use the next consecutive number without renaming any applied migration.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

**S24 (spec)**

Assumption: use the following domain-oriented boundaries; exact Dart signatures and result types will be settled in the approved plan.

Assumption answer: Approved — the user explicitly accepted all spec assumptions.

### Additional plan assumptions

| ID | Assumption | Assumption answer |
| --- | --- | --- |
| P01 | Concrete file/component organization, existing packages and handwritten state, no new dependency or persistent worker. | Approved — user answered yes. |
| P02 | Unicode scalar text limits, explicit tag normalization, embedded-NUL rejection. | Approved — user answered yes. |
| P03 | Task-owned historical schedule snapshots support lazy loading of dates before rule edits. | Approved — user answered yes. |
| P04 | Sheet/dialog breakpoint and width, feature localization delegate with existing formatting support. | Approved — user answered yes. |
| P05 | Application-scoped Undo ownership and injected monotonic active-duration timer. | Approved — keep Undo available across screens for its remaining elapsed time. |


# SECTION 3: TASKS

## Approved inputs and working rules

The user approved [spec.md](spec.md), [plan.md](plan.md), all 24 spec
assumptions, and all five plan assumptions, and explicitly requested this
checklist. Every implementation item started unchecked. Checked items must
represent verified outcomes, not work started. Keep blocked items unchecked
and record the concrete blocker beside them.

Before each implementation session, read
[constitution](../../project/constitution.md), always;
[architecture](../../project/architecture.md) and
[ADR 0001](../../../adr/0001-use-sqlite.md) for structural/data work;
[conventions](../../project/conventions.md) before production code; and
`app/AGENTS.md`. For UI work also read
[design reference](../../project/design-reference.md), both Stitch HTML exports
and images linked by the spec, and the
[calendar specification](../FEATURE%202%20-%20calendar/spec.md).
The approved spec is authoritative: satisfy it or explicitly revise and obtain
approval of the spec before changing behavior or downstream documents.

For every task, follow **Red → Green → Refactor**: confirm the smallest behavior
test fails for the expected reason, implement only what makes it pass, then
refactor without changing behavior. Repeat that cycle for additional behaviors
within the task. Use repository fakes for presentation and real SQLite where
persistence matters; mocks belong only at architectural boundaries. Each test
has one primary behavior and a binary outcome.

Paths below are relative to the repository root; proposed files are created
when their task requires them. Use existing packages, handwritten immutable
state, injected UUIDv7 generation/clock, and the approved layer boundaries:
View → ViewModel → Use Case → Repository → Service. Single-source reads may
skip a use case. No Views access repositories/services, no ViewModels/use cases
depend on services, and repositories never depend on one another.

Run focused tests for each Red/Green cycle and relevant existing regressions
before checking off its validation item. Run `dart format .`, `flutter analyze`,
and `flutter test` from `app/` at the final gate. Store project working artifacts
and screenshots under `.scratches/`. Runtime reload/inspection follows
`app/AGENTS.md`; documentation-only work needs no app reload.

## Implementation record

Implementation is in the isolated worktree
`.scratches/tasks-implementation` on `feature/10-tasks-implementation`.
Terra High implements bounded domain/UI components; Sol High implements data,
recurrence, action coordination, and integration. The baseline's two narrow
calendar accessibility failures were reproduced and fixed. Checked items below
have recorded failing-test/implementation evidence and passing focused checks.
Dart MCP is unavailable, so tooling uses the authorized Flutter/Dart CLI.
Acceptance evidence and rendered comparisons are recorded in
[validation.md](validation.md). The final checks include formatting, clean
analysis, the full test suite, file-backed reopen and Android upgrade/startup.
Visual review also fixed resting swipe edges, missing swipe labels and cadence
chip contrast. Added regression checks exposed and fixed canceled-swipe mutation
and clean-editor Escape dismissal. Changes remain uncommitted in the worktree.

## Task 1: Bounded text, normalized tags, and stable identities

**What to build:** Domain text/identity values with the approved Unicode scalar
counting and tag normalization, independent of Flutter and SQLite.
**Files likely affected:** `app/lib/domain/value_objects/task_id.dart`,
`occurrence_id.dart`, `subtask_id.dart`, `tag_id.dart`, `task_title.dart`,
`subtask_title.dart`, `tag_name.dart`; `app/test/task_value_objects_test.dart`.
**Acceptance criteria:** Blank/overlong/NUL values are rejected; a single display
`#` and surrounding whitespace do not create distinct normalized tags; valid
legacy identity strings and persisted title text remain readable.
**Dependencies:** none.

- [x] Red: test a whitespace-only title and confirm the expected failure.
- [x] Green: implement the minimum title guard; repeat Red/Green for 200-scalar title/subtask, 32-scalar tag and 10,000-scalar notes limits, emoji boundaries, and embedded NUL.
- [x] Test then implement trimmed tag display names, one optional leading `#`, locale-independent lowercase keys, preserved display casing and no accent/canonical folding.
- [x] Test then implement stable ID wrappers accepting existing IDs; distinguish persisted-title hydration from trimming an explicitly saved draft.
- [x] Refactor and verify text/identity tests without infrastructure imports or duplicated UI validation.

## Task 2: Local dates, time windows, reminders, and cadence values

**What to build:** `LocalDate`, date ranges, local minute windows, weekly days,
and valid schedule/reminder settings with calendar-based arithmetic.
**Files likely affected:** `app/lib/domain/value_objects/`,
`app/lib/domain/models/task_schedule.dart`; `app/test/task_schedule_values_test.dart`.
**Acceptance criteria:** Dates/windows/weekly days reject invalid values;
tomorrow and recurrence stepping preserve local dates across boundaries;
reminder offsets require a valid time window. Covers AC-TSK-006–007 and 020.
**Dependencies:** Task 1.

- [x] Red: test an equal-start/end window and confirm it fails.
- [x] Green: implement valid paired minutes 0–1439 with end after start; repeat Red/Green for half windows, overnight windows, invalid dates/ranges, leap days and month/year boundaries.
- [x] Test then implement calendar-date stepping without adding 24 elapsed local hours or converting scheduled dates from UTC instants.
- [x] Test then implement one-time/daily/weekly cadence, nonempty enabled weekly weekdays, start-date lower bounds, optional day-period labels, and legacy repeat-disabled cadence.
- [x] Test then implement Off/0/5/15/30/60-minute reminder preferences, clearing reminders with disabled windows and clearing incompatible daily/weekly settings.
- [x] Refactor and verify pure domain tests, including the approved permissibility of past dates.

## Task 3: Task aggregates, drafts, typed outcomes, and repository contracts

**What to build:** Immutable task/occurrence/checklist models, raw editor drafts,
validated changes, revision expectations, receipts, and the abstract
TaskRepository contract described in the plan.
**Files likely affected:** `app/lib/domain/models/task.dart`,
`task_occurrence.dart`, `task_subtask.dart`, `task_result.dart`;
`app/lib/data/repositories/task_repository.dart`;
`app/test/task_aggregate_test.dart`, test repository fakes.
**Acceptance criteria:** Draft identities survive retry; original slot identity
is separate from effective scheduling; expected validation/not-found/deleted/
stale/transition/Undo/storage failures are explicit values.
**Dependencies:** Tasks 1–2.

- [x] Red: test that retrying the same new draft retains its allocated task/occurrence IDs and confirm failure.
- [x] Green: implement immutable drafts/aggregates and injected UUIDv7 allocation once per new entity; repeat Red/Green for revision and original/effective-date ownership.
- [x] Test then implement field-path validation codes, result variants, mutation receipts, affected dates and prior-state Undo snapshots without UI strings or SQL types.
- [x] Define domain-oriented load/range/schedule/history/save/ensure/change/restore contracts and a fake supporting observable behavior tests.
- [x] Refactor and verify no domain dependency on Flutter/concrete infrastructure and no repository-to-repository dependency.

## Task 4: Task schema and preservation migration in isolation

**What to build:** The next numbered task migration, including schedule history,
transformation of legacy entries/links, constraints and indexes. Test it with
an explicit migration list; leave default startup registration for Task 6 so
the active calendar reader is not broken between tasks.
**Files likely affected:**
`app/lib/data/services/database/migrations/migration_0004_create_task_tables.dart`;
`app/test/task_schema_test.dart`, `app/test/task_migration_test.dart`.
**Acceptance criteria:** Legacy field/ID/link values survive conversion; invalid
relational state is rejected; failure restores original schema/data/history.
Covers AC-TSK-030–031.
**Dependencies:** Tasks 1–3.

- [x] Red: upgrade a version-3 fixture with pending/done entries and participant links; assert preserved values and confirm the absent conversion fails.
- [x] Green: create tasks, weekdays, occurrences, subtasks/state, tags/links, task participants and schedule-history tables; transform legacy entries into independent repeat-disabled tasks and occurrences retaining IDs and unknown timestamps.
- [x] Test then enforce scalar text limits, enums/booleans/revisions, explicit null-pair checks, reminder/completion checks, unique original slots, normalized tags, active positions and composite checklist ownership.
- [x] Test then implement history period/mask checks, read indexes, row/link/value comparisons and foreign-key integrity before dropping legacy link/entry tables.
- [x] Inject failures at creation/copy/check/drop stages and verify the migration runner rolls back data, schema, user_version and history together; cover fresh/version-1/version-2/version-3 inputs.
- [x] Refactor; confirm migrations 0001–0003 and their persistent identifiers are unchanged; use the next consecutive number if 0004 was already allocated.

## Task 5: Isolated database reads and canonical task projections

**What to build:** TaskDatabase read operations and LocalTaskRepository mapping
for aggregates, effective-date ranges, schedules, streak rows and checklist
summaries, using explicitly migrated fixtures.
**Files likely affected:** `app/lib/data/services/task_database.dart`,
`app/lib/data/services/database/task_database_operations.dart`,
`app/lib/data/repositories/local_task_repository.dart`;
`app/test/task_database_read_test.dart`, `app/test/task_repository_read_test.dart`.
**Acceptance criteria:** Range reads include moved-in instances and exclude
tombstones; related fields come from a consistent snapshot; storage failure is
unavailable rather than empty. Supports AC-TSK-003 and 032.
**Dependencies:** Tasks 3–4.

- [x] Red: load an occurrence moved into a range from an original date outside it and confirm the missing reader fails.
- [x] Green: implement batched task/range/child reads in a read transaction; repeat Red/Green for title, time, unknown completion time, tag/participant metadata and inactive-subtask exclusion.
- [x] Test then implement current/historical schedule and batched original-date streak reads, preserving repeat-disabled legacy behavior.
- [x] Test then implement the path/request/result isolate adapter: open in worker, enable foreign keys, close in finally, transfer serializable rows rather than live handles.
- [x] Test then translate read/constraint/corrupt-record failures safely with no task content in diagnostics; verify owned connections close on failure.
- [x] Refactor and verify real SQLite readers plus a file-backed isolate/reopen case without per-card queries.

## Task 6: Register migration and switch the calendar reader together

**What to build:** Atomic release cutover to the new schema and canonical
CalendarDatabase joins, retaining calendar filtering, startup initialization,
participant catalog and selected-day counts.
**Files likely affected:** `app/lib/data/services/database/migrations.dart`,
`app/lib/data/services/calendar_database.dart`,
`app/lib/data/repositories/calendar_repository.dart`,
`app/lib/domain/models/calendar_data.dart`, current calendar/database tests.
**Acceptance criteria:** Latest startup uses canonical task tables; upgraded
examples retain cadence/participant/completion data without repeating; existing
calendar behavior passes. Covers AC-TSK-030–032.
**Dependencies:** Tasks 4–5.

- [x] Red: run the calendar reader against a fully migrated fixture with the old entry tables removed and confirm the expected query failure.
- [x] Green: register the new migration and switch calendar reads to canonical joins in the same change; include task/occurrence identities and required card details.
- [x] Test then implement bounded range reads and participant-catalog reads independent of the current visible range; preserve cadence AND participant filter semantics.
- [x] Update latest-schema fixtures/version assertions; retain historical-migration coverage by explicitly selecting historical migration lists instead of weakening assertions.
- [x] Verify fresh/version-1/current startup, once-only examples, unavailable failures, legacy completion-with-unknown-time, and migration-history identifier preservation.
- [x] Refactor and run relevant calendar/startup/database regression tests; leave no independently writable legacy store.

## Task 7: Atomic one-time task capture

**What to build:** Minimal `SaveTask` creation and isolated transactional write
support for a named one-time task with optional notes, priority, window and
reminder preference, using stable draft IDs.
**Files likely affected:** `app/lib/domain/use_cases/save_task.dart`,
task repository/service write paths; `app/test/save_task_test.dart`,
`app/test/task_database_write_test.dart`.
**Acceptance criteria:** A valid task survives reopen as one aggregate;
invalid or failed writes persist nothing; retries retain IDs. Covers
AC-TSK-002, 006–007 and 011.
**Dependencies:** Tasks 3, 5–6.

- [x] Red: save one named task and reopen it from a file-backed database; confirm failure before write support exists.
- [x] Green: validate through domain values and commit parent plus one occurrence in one transaction with injected UUIDv7/clock and UTC provenance.
- [x] Test then implement optional notes/priority/window/reminder round trips, no notification side effects and disabled-window clearing.
- [x] Test then implement stable-ID retries, explicit conflicts and full rollback on write failure, with sanitized diagnostics.
- [x] Test then emit content-free TaskChange only after a changed commit; failure/no-op must emit no success event.
- [x] Refactor and verify domain and real SQLite capture tests without introducing unused workflow implementations.

## Task 8: Shared metadata edits, tags, and conditional saves

**What to build:** Editing saved task metadata and normalized tag links with
expected revisions, preserving participant associations and selected instance
identity. Shared changes intentionally affect historical cards.
**Files likely affected:** `app/lib/domain/use_cases/save_task.dart`, task
repository/service; `app/test/edit_task_test.dart`, `app/test/task_tags_test.dart`.
**Acceptance criteria:** Shared edits retain identities/links; equivalent tags
reuse one record; stale/deleted targets cannot be overwritten or recreated.
Supports AC-TSK-003, 011, 028–029.
**Dependencies:** Task 7.

- [x] Red: save changed metadata with an older task revision and confirm the missing conflict check fails.
- [x] Green: implement compare-and-set shared saves and explicit missing/deleted/stale outcomes; never convert a failed edit into creation.
- [x] Test then implement shared title/notes/priority changes, ten-selected-tag limit, normalized tag reuse and safe concurrent equivalent-name insertion.
- [x] Test then preserve participant IDs/links, original occurrence identity and unknown legacy creation time; update only known update provenance.
- [x] Force failure after link changes and verify rollback and no event; test affected-date/shared-metadata event coverage.
- [x] Refactor and verify metadata/tag tests and calendar projection regressions.

## Task 9: Checklist definitions and per-occurrence completion

**What to build:** Atomic checklist changes in SaveTask: add, rename, order,
deactivate, complete and reopen, with shared definitions and occurrence state.
**Files likely affected:** Task models, `save_task.dart`, repository/service;
`app/test/task_subtasks_test.dart`.
**Acceptance criteria:** Stable subtask IDs retain state through rename/order;
inactive definitions leave historical state intact; parent/subtask completion
remain independent. Covers AC-TSK-016–018.
**Dependencies:** Tasks 7–8.

- [x] Red: reorder two completed subtasks and assert their identities/completion survive; confirm failure.
- [x] Green: implement stable definitions/positions and occurrence states with composite ownership checks; repeat Red/Green for add/rename/remove and the 50-item limit.
- [x] Test then reorder via temporary deactivation inside the same transaction, retain inactive definitions/history and treat missing state/new definitions as pending.
- [x] Test then derive active complete/total summaries, excluding zero-denominator progress, without completing the parent automatically.
- [x] Test then protect explicitly edited instance/checklist state from future schedule reconciliation; roll back parent/child changes on failure.
- [x] Refactor and verify pure/domain plus SQLite checklist tests and preserved participant links.

## Task 10: Lazy daily and weekly materialization

**What to build:** `EnsureTaskOccurrences` with bounded domain expansion,
repository slot insertion and effective-date range reads.
**Files likely affected:** `app/lib/domain/use_cases/ensure_task_occurrences.dart`,
`task_schedule.dart`, repository/service; `app/test/task_recurrence_test.dart`,
`app/test/task_materialization_test.dart`.
**Acceptance criteria:** Daily/weekly starts and weekdays produce one normal
slot per original date; repeats/restarts/races create no duplicates; moved or
deleted slots are not regenerated. Covers AC-TSK-012–013, 020 and 027.
**Dependencies:** Tasks 2–3, 5, 7.

- [x] Red: ensure January 30 through February 2 twice for an enabled daily task and confirm missing/duplicate behavior fails.
- [x] Green: expand only requested local dates and insert absent slots under unique task/original-date keys, retaining existing slot identity.
- [x] Test then implement weekly lower bounds/selected days, repeat-disabled legacy schedules, daily defaults and all-pending new occurrence checklists.
- [x] Test then verify expected schedule revisions under a short write transaction; retry a schedule race once and return conflict on a second race.
- [x] Race separate connections and test moved/completed/tombstoned slots, moved-in range reads and unrelated constraint failures; use a conflict target limited to the slot key.
- [x] Refactor and verify generation stays bounded, leaves task revisions unchanged, emits no event for a no-op, and does not create a refresh-generation loop.

## Task 11: Effective schedule history and protected recurrence edits

**What to build:** Schedule edit planning and transactional reconciliation using
approved `task_schedule_history`, with new rules effective tomorrow.
**Files likely affected:** `app/lib/domain/models/task_schedule.dart`,
`app/lib/domain/use_cases/save_task.dart`, recurrence use case/repository/service;
`app/test/task_schedule_history_test.dart`.
**Acceptance criteria:** Unvisited past dates use the original rule; repeat edits
before tomorrow create no overlapping periods; protected slots retain state
and IDs while untouched future slots follow the new rule. Covers AC-TSK-019.
**Dependencies:** Tasks 8–10.

- [x] Red: change a weekly rule, then first visit an older unmaterialized week and confirm reconstruction fails without history.
- [x] Green: archive nonoverlapping half-open schedule/default snapshots and select the effective rule for each generated original date.
- [x] Test then implement tomorrow boundaries, repeated same-day rule replacement, future-only starts and explicit legacy enable-repeat without implicit expansion on unrelated edits.
- [x] Test then reconcile matching untouched future slots in place, remove only obsolete untouched pending slots, and preserve today/past/completed/moved/deleted/checklist-edited exceptions.
- [x] Test then stop future repeats on one-time cadence, keep selected instance exceptions separate from series defaults, and commit history/metadata/checklist/window changes atomically.
- [x] Race generation with schedule edits; refactor and verify old-rule writes cannot commit after a revision change and historical defaults are retained.

## Task 12: Completion and reopening as idempotent intents

**What to build:** CompleteTaskOccurrence and ReopenTaskOccurrence with
conditional persisted state, injected completion instants and recoverable
previous state for completion.
**Files likely affected:** `app/lib/domain/use_cases/complete_task_occurrence.dart`,
`reopen_task_occurrence.dart`, repository/service;
`app/test/task_completion_actions_test.dart`.
**Acceptance criteria:** Exactly one selected occurrence changes; repeated
target-state intent does not toggle or replace timestamps; reopening clears
completion time without altering subtasks. Covers AC-TSK-021 and 023.
**Dependencies:** Tasks 7–9.

- [x] Red: complete one of two occurrences of a task and assert the other stays pending; confirm failure.
- [x] Green: implement conditional completion with injected UTC instant, occurrence revision and prior-state receipt.
- [x] Test then implement repeated completion no-op and reopening with null completion time, preserving all subtask states.
- [x] Test then reject missing/deleted/stale targets, preserve shared task revision on instance-only changes and mark intentionally modified future instances as protected where required.
- [x] Refactor and verify commit-only events, failure rollback and unchanged legacy unknown-time handling.

## Task 13: Postpone a pending occurrence to local tomorrow

**What to build:** PostponeTaskOccurrence moving only effective placement while
retaining original slot identity and all saved detail.
**Files likely affected:** `app/lib/domain/use_cases/postpone_task_occurrence.dart`,
repository/service; `app/test/postpone_task_test.dart`.
**Acceptance criteria:** Tomorrow derives from current local date; two normal/
moved instances can coexist; completed targets reject postponement. Covers
AC-TSK-024.
**Dependencies:** Tasks 2, 9–10, 12.

- [x] Red: postpone today's recurring occurrence onto tomorrow's existing normal occurrence and confirm the missing move/coexistence fails.
- [x] Green: update only effective date/exception state, retaining window duration, IDs, original date, checklist, tags and participant associations.
- [x] Test then implement already-tomorrow informational no-op and completed/missing/deleted/stale outcomes.
- [x] Test then publish both old/new affected dates and prove ensuring the original range cannot recreate the moved slot.
- [x] Refactor and verify month/year/leap-day date arithmetic with an injected local clock and real SQLite persistence.

## Task 14: Nonblocking scheduling-conflict advisory

**What to build:** Overlap calculation and advisory loading for the editor's
selected effective date, with recurrence materialized before comparison.
**Files likely affected:** Domain window/overlap logic, editor application
coordination, repository window reads; `app/test/task_conflict_advisory_test.dart`.
**Acceptance criteria:** Overlapping pending windows warn but remain saveable;
self, adjacent, untimed, completed and deleted occurrences do not warn. Covers
AC-TSK-008–009.
**Dependencies:** Tasks 2, 5, 10, 12–13.

- [x] Red: test adjacent 15:00–16:00 and 16:00–17:00 windows do not overlap and confirm failure before calculation exists.
- [x] Green: implement the pure interval rule and repeat Red/Green for true overlap and self-exclusion by occurrence ID.
- [x] Test then ensure competing daily/weekly slots on the effective date before reading pending windows, including moved-in instances.
- [x] Test then ignore untimed/done/deleted records and represent unavailable advisory data as a safe result rather than fabricated no-conflict data.
- [x] Refactor and verify overlap remains an advisory, never a validation/write rejection or a promise about every future repeat.

## Task 15: Tombstone deletion and conditional Undo persistence

**What to build:** DeleteTaskOccurrence and UndoTaskOccurrenceAction repository
operations with exact prior-state restoration and task/instance revision checks.
**Files likely affected:** `app/lib/domain/use_cases/delete_task_occurrence.dart`,
`undo_task_occurrence_action.dart`, receipt/token models, repository/service;
`app/test/task_delete_undo_test.dart`.
**Acceptance criteria:** Deletion survives restart without regenerating its
slot; valid Undo restores the same identity/state; stale/expired/replaced Undo
cannot overwrite later changes. Covers AC-TSK-025–028.
**Dependencies:** Tasks 9–13.

- [x] Red: delete an occurrence, reopen storage and ensure its original interval; confirm resurrection/absence of deletion fails.
- [x] Green: persist a tombstone and prior-state receipt, leaving its unique original slot and series intact.
- [x] Test then restore completion or deletion snapshots conditionally, including exception flag, schedule, checklist identity/state and unchanged shared links.
- [x] Test then reject tokens after shared metadata edits, occurrence changes, expiry or replacement; never clone a deleted entity or rewrite newer shared content.
- [x] Inject restore failures and verify atomic rollback and no success event; refactor and verify no physical purge or series-delete behavior.

## Task 16: Derived daily streaks and history reads

**What to build:** Pure CalculateDailyStreak and batched history projection
using original scheduled dates and the active daily scheduling segment.
**Files likely affected:** `app/lib/domain/use_cases/calculate_daily_streak.dart`,
repository/service history reads; `app/test/task_streak_test.dart`.
**Acceptance criteria:** Pending today preserves yesterday's run; gaps/reopen/
deletion break it and valid restoration repairs it; postponed backfill counts
the original date. Covers AC-TSK-014–015.
**Dependencies:** Tasks 10–12, 15.

- [x] Red: verify two completed preceding dates and pending today produce streak two; confirm failure.
- [x] Green: calculate from scheduled dates/completions, counting today only when done and stopping at the first earlier gap.
- [x] Test then cover future exclusion, deletion/reopen/Undo, postponed backfill, daily segment starts, daily→weekly→daily and visibility toggling without data loss.
- [x] Test then batch history for visible task IDs and distinguish unavailable history from a real zero/not-applicable result.
- [x] Refactor and verify no editable/cached-authoritative streak count or need to materialize every past date.

## Task 17: Stable calendar loading and committed refresh composition

**What to build:** Fresh calendar range loads, stable selection/filter state,
change subscriptions, stale-response rejection and dependency composition.
**Files likely affected:** `app/lib/app/dependencies/task_dependencies.dart`,
`app_dependencies.dart`, calendar ViewModel/state;
`app/test/calendar_view_model_test.dart`, `app/test/task_dependencies_test.dart`.
**Acceptance criteria:** Mutations refresh indicators/entries/counts without
losing selection/filters; navigation loads the full visible interval; old
requests cannot overwrite a newer range. Covers AC-TSK-029.
**Dependencies:** Tasks 6, 10–16.

- [x] Red: resolve one initial calendar load, commit an update and reload; confirm captured-future staleness fails.
- [x] Green: inject a fresh loader and shared repository/use cases while keeping the calendar model instance and selection/mode/filters stable.
- [x] Test then ensure visibleDays including adjacent cells before canonical projection reads; retain participant filter options independently of empty ranges.
- [x] Test then subscribe to post-commit events, ignore old async responses, coalesce redundant no-op loads and unsubscribe on disposal.
- [x] Test then distinguish committed-write/following-refresh failure from failed write and prevent automatic action replay.
- [x] Refactor and verify composition uses no forbidden cross-layer/repository dependencies and preserves calendar regressions.

## Task 18: Data-backed Today state and local-day refresh

**What to build:** TodayViewModel loading today's materialized occurrences,
All/Solo/Shared filters and derived counts/progress.
**Files likely affected:** `app/lib/ui/dashboard/view_models/today_view_model.dart`,
task dependency composition; `app/test/today_view_model_test.dart`.
**Acceptance criteria:** Counts reflect filtered durable occurrences; empty
and unavailable states differ; resume/local midnight refresh Today without
resetting an explicitly selected Calendar date. Supports AC-TSK-029 and 032.
**Dependencies:** Tasks 5, 10, 16–17.

- [x] Red: load a durable solo/shared mix and assert filter-specific pending/done counts; confirm failure.
- [x] Green: ensure/read the injected local day and derive immutable Today presentation state and actual progress.
- [x] Test then reload on committed changes and reject stale responses; omit fabricated counts in loading/unavailable states.
- [x] Test then handle resume/day rollover through the injected clock, preserve calendar selection, and dispose subscriptions/timers safely.
- [x] Refactor and verify repository fakes cover state behavior without copying recurrence/streak rules into the ViewModel.

## Task 19: Application-scoped action state and elapsed-time Undo

**What to build:** TaskActionsViewModel coordinating in-flight commands and the
latest five-active-second Undo token across Today/Calendar navigation.
**Files likely affected:** `app/lib/ui/tasks/view_models/task_actions_view_model.dart`,
task dependency composition; `app/test/task_actions_view_model_test.dart`.
**Acceptance criteria:** Switching screens retains remaining Undo time;
device-clock changes do not alter it; focus pauses/replacement/expiry/write
failure follow approved P05/S12/S20.
**Dependencies:** Tasks 12–15, 17.

- [x] Red: delete, advance fake elapsed time two seconds, switch screen consumers and assert roughly three seconds remain; confirm failure.
- [x] Green: compose one application-scoped actions model with injected monotonic timing separate from stored wall-clock instants.
- [x] Test then implement per-occurrence in-flight locks, success/error results and no-op behavior that does not replace a valid token.
- [x] Test then implement latest-token replacement, expiry, keyboard/accessibility focus pauses and accessible timeout extensions with fake time rather than sleeps.
- [x] Test then suspend expiry during Undo writes, preserve remaining time on write failure, clear on success and end tokens on restart/disposal without reversing persisted actions.
- [x] Refactor and verify stale token rejection and normal post-commit refresh for successful Undo.

## Task 20: Editor draft state, prefill, save, and dismissal commands

**What to build:** TaskEditorViewModel owning immutable draft/loading/error/
dirty/saving state, field validation, scope-aware editing and advisory requests.
**Files likely affected:** `app/lib/ui/tasks/view_models/task_editor_view_model.dart`,
`task_editor_state.dart`; `app/test/task_editor_view_model_test.dart`.
**Acceptance criteria:** New/editor defaults and saved prefill are exact;
dirty dismissal preserves data unless discarded; failure retains the full
draft and saving blocks repeat commands. Covers AC-TSK-001–011 and 018.
**Dependencies:** Tasks 7–11, 14, 17.

- [x] Red: simulate a failed save and assert all valid draft fields/IDs remain available for retry; confirm failure.
- [x] Green: implement new/edit loading, domain-driven validation, disabled invalid submission and stable draft identity.
- [x] Test then prefill saved shared/default/occurrence settings, checklist states, legacy repeat-disabled guidance and explicit scope commands without implicit enabling.
- [x] Test then implement clean/dirty dismissal outcomes, save locks, missing/deleted/stale results, successful close outcome and first-invalid-field identifiers.
- [x] Test then debounce advisory reads, ignore stale results and recheck selected-date overlap at submission without blocking a valid save.
- [x] Refactor and verify no draft mutation reaches storage until Save and no UI-specific business validation duplicates domain rules.

## Task 21: Task localization and presentation-safe message mapping

**What to build:** Approved TaskLocalizations delegate for en-US/pt-BR with
feature text, plural counts and domain failure/field-code translation.
**Files likely affected:** `app/lib/ui/tasks/task_localizations.dart`,
`app/lib/app/activity_monitor_app.dart`; `app/test/task_localizations_test.dart`.
**Acceptance criteria:** Feature labels/counts/errors render in both supported
locales; dates/times use Material formatting; reminders explicitly state that
notifications are inactive. Supports AC-TSK-007 and 033.
**Dependencies:** Tasks 3, 20.

- [x] Red: render a pt-BR validation message and plural subtask count and confirm fallback/hardcoded text fails.
- [x] Green: register the feature delegate alongside existing Material delegates; repeat Red/Green for singular/plural counts, action/editor/Undo labels and safe failures.
- [x] Test then add truthful inactive-reminder wording, unknown completion time, scope guidance, legacy enable-repeat and empty/unavailable messages.
- [x] Test then use locale-aware date/time formatting and approved locale fallback without a new localization package.
- [x] Refactor and verify no SQL/error content, technical saving copy or prototype example data reaches user messages.

## Task 22: Shared task-card variants and explicit action menu

**What to build:** TaskCard and accessible menu for pending daily/weekly/
one-time and completed states, driven by presentation data/commands only.
**Files likely affected:** `app/lib/ui/tasks/widgets/task_card.dart`,
`task_actions_menu.dart`; `app/test/task_card_test.dart`.
**Acceptance criteria:** All four variants show saved metadata only; available
menus match state; completion/reopen/actions expose accessible controls and
48-pixel hit targets. Supports AC-TSK-021, 023, 033–035.
**Dependencies:** Tasks 16, 19, 21.

- [x] Red: render a completed card with unknown completion time and assert generic completed feedback plus Reopen; confirm failure.
- [x] Green: implement the four variants, editorial title, checked/struck-through completed treatment and data-backed cadence/priority/tag/participant metadata.
- [x] Test then display real enabled streaks and active subtask fraction/progress, omitting absent metadata and zero-subtask progress.
- [x] Test then expose pending Mark Done/Edit/Postpone/Delete and completed Reopen/Edit/Delete menus; keyboard dismissal returns focus to the trigger.
- [x] Test then disable per-occurrence pending actions and announce results; verify no Archive workflow, fake reminder promise or database access in a card.
- [x] Refactor and verify compact/wide/enlarged-text semantics with project tokens and a local 8–16-pixel radius override.

## Task 23: Responsive editor shell, details, and guarded dismissal

**What to build:** Compact bottom sheet/wide bounded dialog, title/notes/tag/
priority controls and persistent actions backed by TaskEditorViewModel.
**Files likely affected:** `app/lib/ui/tasks/views/task_editor_sheet.dart`,
details widgets; `app/test/task_editor_sheet_test.dart`.
**Acceptance criteria:** Empty create, populated edit, field-error and saving
states are reachable; all dismissal routes honor dirty/saving state; focus and
actions remain reachable with keyboard/enlarged text. Covers AC-TSK-001–006,
010–011 and 033–035.
**Dependencies:** Tasks 20–21.

- [x] Red: attempt Back/Escape while a save is unresolved and assert the editor stays open; confirm failure.
- [x] Green: implement controlled dismissal/PopScope, close/handle/backdrop commands, dirty-draft choices and complete saving locks.
- [x] Test then implement labeled title/notes, select/add tags, priority and inline validation/focus using ViewModel commands, with draft values retained on error.
- [x] Test then show Create/Save and Cancel/Discard with a persistent footer, saving indicator and safe retry outcomes; restore launcher focus or a stable heading on close.
- [x] Test then switch to dialog at 600 logical pixels, cap width at 560 and height at safe available space; verify scroll/keyboard-safe fields and actions.
- [x] Refactor and compare the four modal states to the reference without copying showcase framing/tabs/example content.

## Task 24: Editor scheduling, recurrence, reminders, and checklist controls

**What to build:** Scheduling & Cadence and Subtasks sections, including
separate shared defaults/selected occurrence overrides and scope guidance.
**Files likely affected:** `app/lib/ui/tasks/widgets/task_schedule_fields.dart`,
`task_subtask_fields.dart`, editor sheet;
`app/test/task_editor_schedule_test.dart`, `app/test/task_editor_subtasks_test.dart`.
**Acceptance criteria:** Conditional weekly/daily/time controls edit the correct
scope; reminder preferences persist without delivery; checklist operations stay
draft-only until Save. Covers AC-TSK-007–009, 016–019 and 033–035.
**Dependencies:** Tasks 9–11, 14, 20–23.

- [x] Red: switch to weekly cadence and assert selected weekdays are required and visible; confirm failure.
- [x] Green: implement date/window/duration/reminder controls, weekly days and daily streak/day-period controls in reference order.
- [x] Test then expose separate recurring defaults/occurrence overrides, tomorrow-effective guidance and explicit legacy enable-repeat; make Custom visibly unavailable.
- [x] Test then show a nonblocking conflict advisory without disabling valid Save, and clear saved reminders with a disabled window.
- [x] Test then implement checklist add/rename/check/delete/order with drag plus move-up/down, saved-state prefill and draft-only progress.
- [x] Refactor and verify every scrolled-off section is reachable with large text, keyboard and 48-pixel targets; no notification permissions or platform alerts occur.

## Task 25: Exact-threshold swipes and accessible recovery banner

**What to build:** Swipe wrapper and shared Undo feedback host connected to the
application-scoped action model, retaining explicit controls as alternatives.
**Files likely affected:** `app/lib/ui/tasks/widgets/swipe_task_card.dart`,
`task_undo_banner.dart`, shared feedback host wiring;
`app/test/task_swipe_test.dart`, `app/test/task_undo_banner_test.dart`.
**Acceptance criteria:** Commit occurs once only on release at ≥90 logical
pixels; vertical/partial/cancel gestures do not mutate; Undo is reachable and
retains its countdown across screens. Covers AC-TSK-021–022, 025–028 and 034.
**Dependencies:** Tasks 19, 21–22.

- [x] Red: release at 89 versus exactly 90 logical pixels and assert only the latter commits; confirm failure.
- [x] Green: implement horizontal foreground tracking, green Done/terracotta Delete canvases and absolute release thresholds without a fling shortcut.
- [x] Test then cover cancellation/vertical scroll, right swipe on completed no-op, child checkbox/menu independence and one pending command per occurrence.
- [x] Test then animate/restyle/remove only after persistence succeeds; restore resting state on error and respect reduced motion.
- [x] Test then render one inverse-surface recovery banner above navigation/keyboard, announce outcomes and connect focus/timeout/Undo-in-flight behavior to the shared model.
- [x] Refactor and verify explicit actions produce identical persisted outcomes, no mandatory haptic dependency, and cross-screen countdown is not reset.

## Task 26: Calendar card/editor integration

**What to build:** Replace calendar agenda tiles with shared cards and add
selected-date creation/edit launchers using approved composition and feedback.
**Files likely affected:** `app/lib/ui/calendar/views/calendar_view.dart`,
task dependency/feedback wiring; `app/test/calendar_view_test.dart`,
`app/test/calendar_task_actions_test.dart`.
**Acceptance criteria:** Calendar launches creation on its selected date;
actions update filtered cards/indicators/counts; selection/filter state and
existing accessible navigation remain intact. Covers AC-TSK-001 and 029.
**Dependencies:** Tasks 17, 22–25.

- [x] Red: create a task for a selected non-today date through Calendar and assert its card/indicator/count appear without resetting filters; confirm failure.
- [x] Green: wire creation and card edit/actions through ViewModels/use cases using shared components, no direct repository access in the view.
- [x] Test then complete/reopen/postpone/delete/restore matching occurrences and verify both affected dates' indicators/counts plus current filters.
- [x] Test then preserve participant options, adjacent-date navigation, week/month selection and empty/unavailable distinctions during refresh.
- [x] Refactor and verify all existing calendar presentation/accessibility regressions and safe focus fallback when a launching card disappears.

## Task 27: Persisted Today cards/editor integration

**What to build:** Replace hardcoded Today tasks/counts with TodayViewModel,
shared task cards/editor and the same feedback/action scope as Calendar.
**Files likely affected:** `app/lib/ui/dashboard/views/dashboard_view.dart`,
task dependency composition, dashboard tests;
`app/test/today_tasks_view_test.dart`, `app/test/task_workflow_integration_test.dart`.
**Acceptance criteria:** Today shows actual due-today data and filtered
progress; creation defaults to local today; navigation preserves shared Undo
and does not treat sample cards as user data. Covers AC-TSK-001, 029 and 032.
**Dependencies:** Tasks 18, 22–26.

- [x] Red: load an empty task store and assert Today has no sample tasks or fabricated progress; confirm failure against the current dashboard.
- [x] Green: bind persisted cards, real counts/progress and localized empty/unavailable states while retaining the existing shell/title/navigation.
- [x] Red/Green: before wiring shared Today/editor actions, add a file-backed journey through Today that creates a recurring task, changes its rule, deletes one occurrence and reopens storage; confirm the missing integration fails, then connect it and verify historical reconstruction/deleted-slot protection.
- [x] Test then wire All/Solo/Shared filters and local-today creation plus edit/action launchers through the approved ViewModels.
- [x] Test then navigate Today→Calendar during an Undo window and verify remaining time/shared state, committed changes and absence of action replay after a refresh failure.
- [x] Test then refresh Today on resume/local-day rollover without changing an explicit Calendar selection.
- [x] Refactor and verify foundation/navigation/localization regressions without adding focus-session or collaboration workflows.

## Task 28: Requested Today and Calendar control refinements

- [x] Add regression checks for floating creation on both screens, Calendar
  header creation with the selected date, and themed Today filter states.
- [x] Implement floating creation using the shared Scaffold slot, preserving
  date defaults and loading/error guards; move Undo above it and reserve scroll
  space. Source review and static analysis pass; runtime verification pending.
- [x] Replace Calendar's Today action with Create task and implement the Stitch
  pill treatment with independent rounded segments and 48-pixel touch targets.
- [x] Apply Calendar's selected/unselected filter colors to Today.
- [x] Run Dart formatting and Flutter analysis successfully.
- [ ] Confirm expected Red failures and passing regression/full tests.
  Blocked: sandbox rejects Flutter's local test server socket (errno 1).
  Both focused and full test attempts failed during loading, before assertions.
- [ ] Verify rendered compact/enlarged-text layouts and matching-viewport
  screenshots. Blocked by the same runtime restriction; no running app or Dart
  MCP was available for hot reload. Reference HTML/image were inspected.

## Task 29: Use the built-in Calendar segmented button

- [x] Add a widget regression requiring a real `SegmentedButton<bool>` with
  Month/Week selection, the reference's inset white selected pill and no
  checkmark; retain selected-date/navigation coverage.
- [x] Replace custom TextButton interaction/semantics with `SegmentedButton`,
  decorating its labels to preserve fully rounded selected ends and shadow.
- [x] Run formatting and static analysis; both pass.
- [ ] Verify widget/full tests and inspect a rendered reference comparison,
  compact layouts and enlarged text. Attempts are blocked before assertions
  because the sandbox forbids Flutter's local test socket (errno 1).

The requested commit/push before this replacement was attempted but Git could
not create `index.lock`: the linked worktree's Git metadata is mounted read-only.
Nothing was committed or pushed, and all implementation changes remain local.

## Task 30: Fit the Calendar toggle capsule to its labels

- [x] Add a regression that the visible capsule hugs the label height while
  the native segmented button retains a 48-pixel touch target.
- [x] Reduce label padding and size the neutral capsule to scaled typography,
  independently of the native touch target; preserve both selection states.
- [x] Run formatting and static analysis; both pass.
- [ ] Confirm Red/Green/full tests and reference/large-text rendering. Focused
  and full suite attempts fail before assertions because this sandbox forbids
  Flutter's local server socket. Runtime and hot reload remain unavailable.

## Task 31: Slightly enlarge the Calendar toggle and selected pill

- [x] Increase label typography and pill padding together, keeping the visible
  capsule between the earlier oversized and undersized versions.
- [x] Update the sizing regression; formatting and static analysis pass.
- [ ] Verify tests and rendered sizing. Full tests were attempted; execution
  remains blocked by the sandbox's restriction on Flutter's local test socket.
  No running app/Dart MCP is available for hot reload or screenshot comparison.

## Task 32: Slide the selected Calendar mode pill

- [x] Add regression checks for intermediate movement in both directions,
  native selection, and immediate updates with reduced motion enabled.
- [x] Animate a single decorative pill beneath the native segmented button,
  retaining current sizing, keyboard behavior and selected-date preservation.
- [x] Formatting and static analysis pass; focused and full tests attempted.
- [ ] Verify animation tests and rendered movement. Test loading is blocked by
  the sandbox's local socket restriction, before assertions. No running app or
  Dart MCP is available for hot reload or visual verification.

## Task 33: Remove the oversized mode-chip click highlight

- [x] Remove native ripple/state overlays that paint beyond the visible chip,
  retaining the sliding selection, native hit targets and keyboard focus cue.
- [x] Update the regression; formatting and static analysis pass.
- [ ] Verify widget/full tests and click/keyboard rendering. Test attempts
  remain blocked at loading by the sandbox's local socket restriction.
  No runtime is available for hot reload or screenshot verification.

## Final validation and handoff

After Tasks 1–27, validate the completed feature and record evidence. This
verification gate does not require inventing a failing test for behavior
already proven by the implementation tasks.

The feature is complete only when the spec and all acceptance criteria are
satisfied, formatting/analysis/new and existing tests pass, documentation is
synchronized, and no known constitution violation remains.

- [x] Run the file-backed workflow integration test and verify old unmaterialized dates, deleted-slot protection, shared-screen refresh and persistence after reopening.
- [x] Map AC-TSK-001–035 to passing evidence, including atomic child-write failure, stale Undo and inaccessible storage; retain historical migration tests and existing regressions.
- [x] If validation reveals a defect, reproduce it with a failing regression test before fixing it, then refactor after Green; do not add implementation-mirroring tests.
- [x] Capture all four card variants and create/edit/error/saving modals at reference viewports under `.scratches/`; manually compare both Stitch HTML/images, including all hidden-by-scroll fields, narrow/wide/large-text/keyboard layouts and accessible focus/Undo.
- [x] Document upgrade/canonical schema, inactive notification delivery, legacy repeat opt-in and deliberate backup-based rollback in `app/README.md`; record visual deviations or environmental blockers beside unchecked items.
- [x] Run `dart format .`, `flutter analyze`, and `flutter test` from `app/`; check items only after verified success and synchronize spec/plan/task status without marking unresolved work complete.

## Review checkpoint

Before handing this checklist to an implementing agent, manually verify the two Stitch exports, the shared-versus-occurrence edit guidance, legacy recurrence opt-in, tomorrow-effective schedule changes, original-date streak backfill, and cross-screen remaining-time Undo against the approved spec and plan.

## Acceptance coverage

| Spec scenarios | Primary implementation/verification tasks |
| --- | --- |
| AC-TSK-001–003 | 7–8, 20, 23, 26–27 |
| AC-TSK-004–005 | 20, 23 |
| AC-TSK-006–007 | 1–2, 7, 20–21, 24 |
| AC-TSK-008–009 | 14, 20, 24 |
| AC-TSK-010–011 | 7–9, 20, 23 |
| AC-TSK-012–013 | 10–11, 27 |
| AC-TSK-014–015 | 12, 15–16, 22 |
| AC-TSK-016–018 | 9–10, 20, 22, 24 |
| AC-TSK-019–020 | 2, 10–11, 24, 27 |
| AC-TSK-021–024 | 12–13, 19, 22, 25–27 |
| AC-TSK-025–028 | 10, 15, 19, 25–27 |
| AC-TSK-029 | 17–19, 26–27 |
| AC-TSK-030–032 | 4–6, 17–18, 26–27 |
| AC-TSK-033–035 | 21–27 and final visual validation |

## Assumptions to review

All entries below have already been reviewed and accepted; none is pending.
They are retained for traceability and for any later amendment, with high-impact
decisions first. P05 includes the user's explicit clarification answer.

1. Assumption: **S08** — title, notes, tags, priority, reminder/time defaults, and subtask definitions belong to the recurring task and are shared across its cards, including historical cards. Recurrence changes take effect from tomorrow, preserving past and today's occurrences, completed occurrences, and explicitly moved/deleted occurrences. The selected occurrence's date/time can be edited as an exception without moving the series. A one-time task's date/time edit moves its only occurrence. — Impact: HIGH
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

2. Assumption: **S14** — each legacy calendar entry becomes an independent task with one stored occurrence; its cadence label is preserved, but automatic recurrence stays disabled until the user explicitly enables it in the editor. Existing example entries remain identifiable as examples and MUST NOT expand automatically. A legacy non-repeating daily/weekly task shows explanatory guidance and an explicit Enable repeating schedule control; opening and saving unrelated details does not implicitly enable it. — Impact: HIGH
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

3. Assumption: **S16** — a streak is consecutive original scheduled local dates completed for one enabled daily task. If today's occurrence is pending, the run ends yesterday; if it is completed, it ends today. Missing, pending, or deleted earlier dates break the run; future dates are excluded. A postponed occurrence counts for its original date when eventually completed, allowing intentional backfill. No completion before the daily schedule's effective start contributes. — Impact: HIGH
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

4. Assumption: **S12** — deletion removes only one occurrence, never the series; completed is not a separate archived lifecycle. Completion Undo also lasts five seconds. Only the latest undoable action has an active banner; replacing it ends the previous window. Windows pause while the banner has keyboard or assistive-technology focus and respect accessible timeout extensions. — Impact: HIGH
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

5. Assumption: **S20** — restarting closes outstanding Undo windows; committed deletion remains effective. Recovery of an entire recurring series is not needed because deleting a series is not exposed in this feature. — Impact: HIGH
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

6. Assumption: **S22** — use `tasks` as recurring definitions and `task_occurrences` as materialized dated instances. Normalize tags, weekdays, and checklist state as below; reuse `calendar_participants` to preserve existing participant identity. This replaces the legacy writable entry tables instead of maintaining two competing task stores. — Impact: HIGH
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

7. Assumption: **P03** — Extend the proposed schema with `task_schedule_history`, a task-owned archive of scheduling snapshots, so the approved past-preservation behavior also holds for dates that were never materialized before an edit. This is persistence for the existing recurrence requirement, with no additional user-facing workflow. — Impact: HIGH
   Assumption answer: Approved — user answered yes.

8. Assumption: **P05** — Keep one application-scoped TaskActionsViewModel for the latest Undo token/banner so navigation between Today and Calendar does not reset its remaining recovery window. Use an injected monotonic elapsed timer, separate from the wall clock used for stored instants. — Impact: HIGH
   Assumption answer: Approved — keep Undo available across screens for its remaining elapsed time.

9. Assumption: **S07** — daily means every calendar day; weekly means every week on the selected weekdays; new weekly tasks initially select the scheduled date's weekday. Day-period preferences are labels and do not infer a time window. The chosen start date is a lower bound: a weekly task's first occurrence is its first selected weekday on or after that date. New daily/weekly tasks enable recurrence on save. — Impact: HIGH
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

10. Assumption: **S23** — the next migration is `migration_0004_create_task_tables.dart` / `Migration0004CreateTaskTables`, registered as `0004_create_task_tables`. If another migration lands first, use the next consecutive number without renaming any applied migration. — Impact: HIGH
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

11. Assumption: **S02** — task creation is personal and local to one device. Existing participant associations remain visible and survive edits, but this editor has no participant assignment, invitations, synchronization, or authentication. Task details, focus timers, a separate archive, arbitrary custom recurrence, and notification delivery are outside this feature. Custom cadence is visibly unavailable rather than selectable without functioning behavior. — Impact: HIGH
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

12. Assumption: **S01** — creation is available from Today and Calendar; Calendar creation defaults to its selected date, and Today creation defaults to the current local date. Today lists occurrences due today and derives its task counts/progress from those occurrences. Existing dashboard section labels may adapt to actual data; unrelated navigation and focus-session features remain unchanged. — Impact: HIGH
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

13. Assumption: **S17** — deleting a definition removes it from all displayed checklists but retains historical state internally; unchanged definitions retain completion, and added definitions start pending. — Impact: HIGH
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

14. Assumption: **S15** — travelling leaves scheduled wall dates/times unchanged; no time-zone identifier or cross-device scheduling is introduced. — Impact: MEDIUM
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

15. Assumption: **P02** — Count bounded text in Unicode scalar values (`runes.length`), not UTF-16 code units or grapheme clusters. Trim title, subtask, and tag values with the shared domain normalizer. Tag input may include one leading display `#`, which is removed before normalization; its key is the remaining trimmed name lowercased with Dart's locale-independent `toLowerCase()`. Preserve display casing and do not introduce Unicode canonical normalization or accent folding. Reject embedded NUL in bounded text because its storage length semantics would differ. Preserve notes' internal whitespace and line breaks. — Impact: MEDIUM
   Assumption answer: Approved — user answered yes.

16. Assumption: **S04** — titles are trimmed and limited to 200 characters; notes to 10,000 characters; tags to 32 characters and ten selected tags per task. Tag identity uses trimmed, case-insensitive names without a leading display `#`; original display casing is preserved. — Impact: MEDIUM
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

17. Assumption: **S09** — up to 50 subtasks, each with a trimmed nonblank title of at most 200 characters; new recurring occurrences start with all subtasks pending. Accessible move-up/down actions accompany drag ordering. — Impact: MEDIUM
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

18. Assumption: **S05** — windows are within one local calendar day; overnight windows are rejected with field guidance. Past dates are permitted. — Impact: MEDIUM
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

19. Assumption: **S06** — options are Off, At start, 5, 15, 30, or 60 minutes before, defaulting to Off; the reference's Calm Chime is a future delivery treatment, not a sound selector. — Impact: MEDIUM
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

20. Assumption: **S10** — parent and subtask completion are independent; completing all subtasks does not automatically complete the parent, and completing or reopening a parent does not change its subtasks. — Impact: MEDIUM
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

21. Assumption: **S11** — an occurrence already due tomorrow produces an informational no-op. A moved recurring occurrence may coexist with tomorrow's normal occurrence; they remain distinct and MUST NOT be merged. — Impact: MEDIUM
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

22. Assumption: **S13** — before saving, close, backdrop, Back/Escape, and sheet dragging discard a clean draft immediately; dirty drafts require Keep editing or Discard changes. — Impact: MEDIUM
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

23. Assumption: **S18** — the advisory checks the selected occurrence's effective date, not every future repeat. — Impact: MEDIUM
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

24. Assumption: **S19** — pending cards precede completed cards; within each group timed occurrences sort by start time, untimed occurrences last, then title and identity. — Impact: LOW
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

25. Assumption: **S03** — defaults are low priority, one-time cadence, no tags or subtasks, no time window, no reminder, and streak tracking off. — Impact: LOW
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

26. Assumption: **S21** — the following feature-specific components implement the requested behavior using existing Riverpod composition, the injected UUID generator, database initialization, localization, and shared theme. No new package is required by this proposal. — Impact: MEDIUM
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

27. Assumption: **S24** — use the following domain-oriented boundaries; exact Dart signatures and result types will be settled in the approved plan. — Impact: MEDIUM
   Assumption answer: Approved — the user explicitly accepted all spec assumptions.

28. Assumption: **P01** — Implement the following concrete organization using the existing dependencies and handwritten immutable state classes. Add no package, ORM, generated-model requirement, or persistent database worker for this feature. — Impact: MEDIUM
   Assumption answer: Approved — user answered yes.

29. Assumption: **P04** — Switch from bottom sheet to bounded dialog at 600 logical pixels of available width; cap the dialog at 560 logical pixels and at the available safe height. Use a dedicated `TaskLocalizations` delegate with en-US and pt-BR strings and plural methods, added alongside the existing Material delegates. Use Material localizations for date/time formatting; no new localization dependency is needed. — Impact: MEDIUM
   Assumption answer: Approved — user answered yes.


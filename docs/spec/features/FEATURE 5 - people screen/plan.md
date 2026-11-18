# SECTION 2: PLAN

> Delivery update (2026-11-18): after local validation, the user explicitly
> authorized committing and pushing each feature on its own issue branch. Earlier
> local-only restrictions below describe the implementation phase. People is
> delivered on `feature/8-people-screen`, based on `feature/7-home-screen`.
> Issue/project/PR mutations remain outside this authorization.

## Status and required context

Approved to proceed by the user's 'Continue, dont stop' instruction, using
the proposed [specification](spec.md) and choices PEO01–PEO07, PP01–PP02.

Before implementation, read the [constitution](../../project/constitution.md),
[architecture](../../project/architecture.md),
[conventions](../../project/conventions.md),
[SQLite ADR](../../../adr/0001-use-sqlite.md), `app/AGENTS.md`, the specification,
and the [design reference](../../project/design-reference.md). Inspect both
Stitch People HTML and image. The specification governs behavior; revise and
obtain approval of an upstream behavior change before implementing it.

All changes remain local. Do not commit, push, create/edit/close GitHub items,
or create pull requests. Preserve the user's existing `app/pubspec.lock`
changes and unrelated generated artifacts. No dependency upgrade is planned.

## Architecture impact

No changes to architectural boundaries. Add People using the established flow:

```text
PeopleView / PersonDetailSheet / PersonEditorSheet
  → PeopleViewModel / PersonDetailViewModel / PersonEditorViewModel
  → BuildPeopleDirectory (use case)
  → PeopleRepository
  → PeopleDatabase (worker-isolate SQLite operations)

TaskEditorSheet → TaskEditorViewModel → SaveTask
  → TaskRepository → TaskDatabase
```

`PeopleRepository` owns person reads/writes and read-only person activity
projections. It MUST NOT call `TaskRepository`. Its service reads existing task
tables and reuses row mappers to return domain aggregates for history. Task
writes continue through `TaskRepository`, with no duplicate mutation logic.
History page loading needs no wrapper use case: its ViewModel can call its
single repository directly. `BuildPeopleDirectory` owns search/filter
calculations; `PersonDraft` owns shared input validation; person saving uses its single
repository directly without a redundant use-case wrapper. Composition supplies
a stable UUIDv7 once at draft creation.
Views only render state and forward commands.

Composition in `app/dependencies/people_dependencies.dart` supplies the shared
database path, injected UUIDv7 generator, clock, repositories and ViewModels.
Change streams invalidate affected ViewModels at the composition boundary;
repositories do not depend on each other.

## Data model changes

### Person types

Add immutable domain types under `domain/models` and `domain/value_objects`:

- Person identity uses the existing nonblank participant string identity,
  retaining legacy IDs unchanged instead of introducing a competing ID type.
- `PersonDraft` owns trimmed nonblank name validation (at most 100 Unicode
  scalars) and optional role validation (at most 100 Unicode scalars). Legacy
  `Person` records can still represent names exceeding the new editor limit.
- `PersonCategory`: stable Work/Household/Creative/Family values, translated
  only in presentation.
- `Person`: identity, name, role, immutable category set and revision.
- `PersonDraft`: editable input, stable identity, nullable expected revision
  (`null` means create). Generate the identity once when starting a draft.
- `PeopleSnapshot`: people, per-person pending-today counts, qualifying recent
  completion counts, last-activity summaries, and global today occurrence totals.
- `PersonActivityPage`: at most 20 task aggregates, total count, page and order.

Domain validation owns name/role invariants; share validation with editor
feedback. Reuse existing scalar-count/search helpers where suitable. Add a
tested accent-insensitive search helper if needed rather than a new package.

### Migration 0005

Create `migration_0005_add_people_metadata.dart`, class
`Migration0005AddPeopleMetadata`, registered after migration 0004:

- Keep `calendar_participants` as the identity/name table, retaining all IDs
  and existing foreign keys.
- Add nullable `role` with trimmed length constraint and nonnegative `revision`
  defaulting to zero. Legacy names remain readable even when longer than the
  new editor limit; editing a name requires satisfying the new limit.
- Add `person_categories(participant_id, category)` with participant foreign
  key, composite primary key and allowed-category constraint.
- Retain `task_participants` and its uniqueness/foreign-key constraints.
  Inspect query plans before introducing an additional index.
- Add no sample people and do not reset or rewrite task data.

Run the additive migration in the existing transaction mechanism. Test fresh
creation and upgrade from v4 with legacy people, multi-person links and
completed/deleted occurrences. Failure MUST roll back schema/data changes.
Runtime downgrade is unsupported; do not automatically drop metadata. Recovery
uses a verified pre-upgrade backup with the app stopped. Never reset a user's
database to make validation pass.

### Task assignments

Extend `TaskDraft`, its factories/copy methods, `SaveTask`, prepared-save
transport and the commit transaction with immutable participant-ID selections.
Edit drafts start with saved membership; new drafts start empty. Deduplicate
IDs, verify selected identities exist, and replace membership inside the same
transaction as the task save. Task revisions MUST reject stale selections.
Retain existing Task change notifications.

Membership applies to all occurrences, including saved history. Explain that
scope for recurring tasks. Do not store per-occurrence person completion.
Before implementation, revise the Tasks specification's assignment exclusion
to reference approved REQ-PEO-004, preserving all other task guarantees.

## Application contracts

Use explicit People result/failure types independent of UI and SQL. Expected
codes: validation with field map, notFound, staleRevision, identityConflict and
storageUnavailable. Diagnostics contain operation/code/type only, never personal
or task content.

| Contract | Input → output | Failures and guarantees |
| --- | --- | --- |
| `PeopleRepository.loadSnapshot(today)` | LocalDate → PeopleSnapshot | Unavailable is distinct from empty; one consistent read transaction. |
| `PeopleRepository.loadPersonActivities(query)` | Person identity, page, size 20, order → PersonActivityPage | Not found/unavailable; page count, clamp and read share a transaction. |
| `PeopleRepository.savePerson(prepared)` | Validated person, expected revision → Person | Atomic metadata/categories; validation, identity conflict, stale revision, not found or unavailable. |
| `PeopleRepository.changes` | Stream → person identity/revision change | Emit after commit only; dispose with repository. |
| `BuildPeopleDirectory.execute(snapshot, query, filter, labels)` | Snapshot and active-language category labels → cards and overview | Pure deterministic projection; no storage or clock access. |
| `PersonEditorViewModel.save()` | PersonDraft → success/failure state | Uses shared domain validation and PeopleRepository; retain the same create identity across retries. |
| Extended `SaveTask.execute(draft)` | Existing draft plus participant IDs → TaskSaveResult | Missing people fail without partial task writes; retain revision checks. |

`PeopleDatabase` follows the existing path-based worker-isolate service and
connection cleanup patterns. Snapshot queries use one read transaction for
people/metadata, grouped counts and last-activity candidates. Use effective
dates for today, frequency and last activity. History reads do not expand
recurrence; map only the selected page's aggregates.

Directory order is case-insensitive name ascending then stable ID.
[ASSUMPTION: PP01 — use deterministic alphabetical directory order; the
user-facing sort controls activity history rather than adding directory sort.]

History SQL ordering MUST match approved date/time/title/ID examples, including
untimed entries following timed entries even when dates/times sort descending.

## Presentation and state

- `PeopleViewModel` owns one immutable state: availability, snapshot, search,
  filter, projected cards and local day. Retain it across destination navigation.
  Mark failed refreshes explicitly; retained data must not appear fresh.
- Search/filter project loaded data immediately without database reads. Keep
  text, focus and scroll controllers in views; business state remains in the
  ViewModel. Stable widget identities preserve keyboard focus.
- `PersonDetailViewModel` owns history page/order/loading/failure and guards
  async reads with sequence IDs/disposal checks. Clamp pages after changes.
- `PersonEditorViewModel` owns validation, dirty/save state, retained drafts,
  duplicate-submit protection and stale-write feedback. Do not automatically
  overwrite a newer person revision; require explicit reload.
- Match Stitch's hierarchy: search, two overview cards, full-width Work Dynamic,
  category chips and person cards. Label time-scoped metrics explicitly as today.
- Open details and create/edit in scrollable sheets, keeping the directory
  mounted. Details expose Edit Person and paged history; history activity actions
  reuse existing task editor, mutation ViewModel and shared Undo feedback.
  [ASSUMPTION: PP02 — use modal sheets instead of new top-level routes, with
  constrained width on wide screens and keyboard-aware scrolling on compact
  screens.]
- Task editor multiple-person selection uses real choices with search. Empty
  choices guide users to People. A failed choices load MUST NOT clear saved
  membership. Metadata-only task edits may preserve unchanged membership;
  changing membership requires successfully loaded choices.
- Add `PeopleLocalizations` following Home/Tasks patterns. Reuse theme tokens,
  shared dates and initials from actual names. Omit unsupported photo, presence
  and notification controls. Wrap chips/metrics and stack actions at large text.
- Composition listens to People and Task changes. Person edits invalidate
  affected task views because aggregates include names; task changes refresh
  People and open history. Use injected clocks, pause/resume handling and a
  local-midnight timer. Discard/reload reads that cross into a new local day.

## Patterns to follow

Follow `LocalTaskRepository` result mapping/events, `TaskDatabase` worker
requests, numbered migration registration, `TodayViewModel` immutable state and
lifecycle guards, `TaskEditorViewModel` retained drafts/guarded saves, and Home
widgets for responsive filters, theme and localization. Do not duplicate task
validation/mutation logic in People components.

## Testing strategy

Every business change follows Red–Green–Refactor: observe the expected failing
test, introduce minimum passing behavior, then refactor without changing the
observable result. Prefer fake repositories for ViewModel/widget tests. Real
temporary SQLite verifies persistence, constraints, migrations and transactions.

| Layer | Verification | Acceptance criteria |
| --- | --- | --- |
| Domain | Name/role limits, categories, accent search, AND filters, frequency boundaries, unique counts, zero-day ratio, last-activity exclusions | 003–009 |
| Service/repository | Fresh/v4 migration, legacy links/names, reopen durability, revisions, atomic failure, history paging/ties and consistent snapshots | 001–003, 006, 008–010, 012, 015 |
| ViewModels | Cancel/save/retry, stale responses, page clamp, retained state, mutation refresh, pause/resume/midnight | 002–004, 008, 010–013 |
| Widgets | Directory/editor/history, task associations and failed choices, Undo, keyboard/focus, both locales, loading/empty/unavailable | 001–004, 008, 010–014 |
| Workflow | Create person → assign → history → complete/reopen/postpone/delete/Undo → reopen storage; stale-write rejection | 002, 009–013, 015 |

Place logs, temporary databases and screenshots under
`.scratches/people-validation/`. Capture fresh reference-size, compact, wide and
320-pixel doubled-text renders in both locales: populated, empty, filtered,
unavailable, create/edit, history, task selection and keyboard states. Compare
against Stitch HTML and image, documenting approved scope adaptations. Verify
contrast, target sizes, selected semantics, visible focus and reachable actions.

Final gates from `app/`: `dart format .`, `flutter analyze`, `flutter test` and
Android debug APK build. Record preexisting SDK deprecation infos separately;
do not suppress new errors/warnings or describe remaining infos as clean
analysis. Native inspection uses `--print-dtd`, Dart MCP when available and
reload/restart per `app/AGENTS.md`. Never reset the device database. Verify the
user's lockfile is byte-identical to its preimplementation snapshot.

## Security and performance constraints

This is offline local companion bookkeeping. No authentication, contact sync,
network permissions or remote authorization are introduced. Membership grants
no access rights. Use bound SQL, validated input and meaningful constraints.
Do not log names, roles, searches, titles, notes or raw exception payloads.

Run database work off the UI isolate. Do not enumerate unbounded recurrence.
Use grouped reads instead of one query per person; do not fetch all historical
aggregates just to count them. Limit history aggregate mapping to 20 entries.
Inspect query plans and use a representative larger fixture to verify bounded
reads without flaky wall-clock assertions. Directory search uses the loaded
person summaries, without copying full task history into presentation state.

## Execution checkpoint

The user directed continued implementation with the proposed choices. Track
verification in `tasks.md` and continue through local validation. GitHub and
commit prohibitions remain. The direct person-save flow and reused participant
identity representation above reflect the final implementation while preserving
the approved behavior and architectural boundaries.

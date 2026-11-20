# SECTION 1: SPEC

## One-line purpose

Let users configure task types with suitable fields, record activity, and
understand their progress through durable logs and metrics.

## Status and sources

Approved by the user on 2026-11-19, including CF01–CF18. Implemented and
validated on 2026-11-20; see the validation notes in [tasks.md](tasks.md). The user explicitly
authorized continuing through plan, tasks, implementation, and delivery without
further spec-writer approval gates.

The user requested a new branch, a specification, implementation, and subsequent
commit, push, and PR completion. The accepted product decisions are recorded in
[Task Types, Custom Fields, and Progress Metrics](../../../grill-me-docs/task-types-custom-fields-and-progress-metrics.md).
Q1–Q26 in that interview are reviewed decisions, not assumptions.

Canonical context:

- [Constitution](../../project/constitution.md)
- [Architecture](../../project/architecture.md)
- [Conventions](../../project/conventions.md)
- [Design reference](../../project/design-reference.md)
- [Tasks](../FEATURE%203%20-%20tasks/spec.md)
- [People](../FEATURE%205%20-%20people%20screen/spec.md)
- [Profile](../FEATURE%206%20-%20profile%20screen/spec.md)
- [Notifications](../FEATURE%207%20-%20notifications/spec.md)

This feature adds task details, typed fields, and activity logs beyond FEATURE
3's original scope. Existing scheduling, occurrence actions, tags, participants,
and reminder behavior remain governed by their specifications except where
explicitly extended below. Task types are independent of companion categories.

(CF01, approved: “Implement the custom fields” includes the accepted supporting
task-type, logging, metrics, structured-field, timer, and finish-task workflows
in this specification, rather than only basic fields in the task editor.)

## Users and use cases

- As a local user, I want to choose a suitable task type so that its setup and
  activity controls match what I am tracking.
- As a local user, I want to create custom types and fields so that I can track
  activities beyond the supplied defaults.
- As a local user, I want to record, correct, and inspect sessions so that my
  metrics reflect the activity I actually performed.
- As a local user, I want progress targets and an optional finish date so that
  I can judge a sustainable pace without automatic completion or failure.
- As a returning user, I want upgrades and type changes to preserve my existing
  tasks and historical measurements.

## Requirements

### Types, defaults, and configuration

1. **REQ-CFL-001 — One task type:** Every task MUST have exactly one type,
   defaulting to General. General MUST add no fields to the existing controls.
   Tags, cadence, priority, participants, and type MUST remain independent.
2. **REQ-CFL-002 — Built-in catalog:** The application MUST provide General;
   Read → Book and Comic; Exercise → Gym and Calisthenics; and standalone Study,
   Work, Watching series, and Cleaning. Read and Exercise MUST be headings, not
   selectable task types. Each selectable type MUST have an appropriate icon.
3. **REQ-CFL-003 — Availability:** Defaults MUST be available after local profile
   setup and on upgrade for existing users, without creating duplicate types.
   Existing tasks MUST become General without losing their current data. This
   feature MUST NOT require online accounts or connectivity.
4. **REQ-CFL-004 — Immutable defaults:** Users MUST NOT rename or edit built-in
   types or their fields. They MUST be able to hide and restore built-in types
   in the picker without changing tasks already using them. General MUST remain
   available. (CF02, approved: General cannot be hidden because it is the
   fallback for untyped and existing tasks.)
5. **REQ-CFL-005 — Catalog notices:** A newly introduced built-in type MUST
   produce a dismissible in-app notice. Dismissal MUST survive restart. Initial
   catalog installation MUST NOT be presented as a batch of new-type notices.
   (CF03, approved: Initial installation is silent; later catalog additions
   are announced once per installation, including types hidden afterward.)
6. **REQ-CFL-006 — Custom types:** Users MUST be able to create and rename
   custom types, choose an icon, and optionally place them under one grouping
   heading. Types sharing a heading MUST NOT inherit fields automatically.
   (CF04, approved: Type and heading names are trimmed, nonblank, limited to
   64 characters, and unique ignoring case within their respective collections;
   custom types cannot reuse a built-in type name. Users choose icons from an
   accessible supplied set rather than uploading images.)
7. **REQ-CFL-007 — Basic fields:** Users MUST be able to configure text, number,
   date, checkbox, and single-choice fields. Each field MUST have a label and
   belong either to task setup or individual activity logs. Forms MUST be
   generated from those definitions. (CF05, approved: Fields may be reordered
   and marked required; labels are trimmed, nonblank, unique within a type
   ignoring case, and at most 64 characters. A type has at most 30 active fields,
   text values at most 10,000 characters, and choice fields 1–50 distinct
   nonblank options of at most 100 characters each.)
8. **REQ-CFL-008 — Numeric configuration:** Numeric fields MUST support a unit,
   optional target, and a selected summary of total, latest, average, or highest.
   Numeric fields MUST support charts over time. Numeric values and targets
   MUST be finite. (CF06, approved: Signed decimal values are supported for
   generic numbers; units are display labels of at most 32 characters and are
   never automatically converted. Domain-specific counts and durations have
   their own nonnegative or positive constraints.)
9. **REQ-CFL-009 — Structured fields:** Custom types MUST also support reusable
   exercise-set, episode-list, and checklist fields with predefined controls.
   Built-in types MUST use the same field capabilities wherever possible.
10. **REQ-CFL-010 — Schema evolution:** Custom-type changes MUST affect future
    entries while historical logs retain their recorded field labels, units,
    kinds, and values. Removed fields MUST be retired without deleting history.
    Changing a field kind or unit MUST create a replacement field, and MUST NOT
    merge incompatible measurements. (CF07, approved: Historical log edits
    continue to use that log's recorded field definitions. Existing task setup
    values remain readable; new required fields must be supplied on the next
    explicit setup save, without blocking unrelated occurrence actions.)
11. **REQ-CFL-011 — Change type:** Users MUST be able to change a task's type
    after a warning about the effect on future forms and metrics. Existing
    logs MUST remain readable under their original definitions; future logs
    MUST use the new type. Incompatible metrics MUST remain separate.
    (CF08, approved: Switching types does not copy values by matching labels;
    previous setup values remain readable as history and new setup values are
    entered explicitly.)

### Task detail and activity logs

12. **REQ-CFL-012 — Details:** Opening a task MUST expose its progress summary,
    Record progress action, and log history. Existing task editing and
    occurrence completion controls MUST remain accessible. A cross-task metrics
    dashboard is outside this feature.
13. **REQ-CFL-013 — Logging:** Users MUST be able to create several sessions per
    task per day, record past sessions, and edit or delete mistaken entries.
    Each log MUST identify its task, session date/time, and recorded values.
    (CF09, approved: Future session timestamps are rejected; session ordering
    uses recorded instants, with stable identity as a tie-breaker. Logs belong
    to the task and may optionally reference the occurrence from which they
    were opened, without requiring an occurrence for every session.)
14. **REQ-CFL-014 — Independence:** Recording or deleting progress MUST NOT
    complete, reopen, move, or delete an occurrence. Completing an occurrence
    MUST NOT invent a progress log or change previously recorded measurements.
15. **REQ-CFL-015 — Summaries:** Task details MUST derive numeric summaries and
    charts from saved values, update after log creation/edit/deletion, and
    retain text, choice, date, and checkbox values in log history. Empty metrics
    MUST show an empty state rather than invented activity. [ASSUMPTION CF10:
    Charts initially show chronological session values across the task's whole
    history; absent optional values are excluded, zero values are included,
    and an empty summary displays no numeric result. Setup numeric fields show
    their current value; session summaries and charts use log fields.]
16. **REQ-CFL-016 — Main target:** Each task MAY designate one numeric metric
    as its main progress target. Other numeric metrics MUST retain their own
    summaries and charts. Initial pace calculations MUST be restricted to
    additive progress toward a known total.

### Built-in tracking behavior

17. **REQ-CFL-017 — Books:** Book tasks MUST support total pages and current
    page per session. The first entry MUST establish a starting baseline without
    counting earlier pages as new reading. Subsequent entries MUST derive pages
    read from preceding progress. Corrections, deletion, and backdated entries
    MUST recalculate affected metrics. (CF11, approved: An explicit starting
    page, defaulting to zero, establishes the baseline during setup. Current
    pages are whole numbers within zero and total pages and cannot decrease
    chronologically; corrections that violate that sequence are rejected with
    guidance. Separate rereading entries record additional pages without
    advancing the current page or the completion percentage.)
18. **REQ-CFL-018 — Comics and series:** Comic tasks MUST choose issues or
    volumes as their tracking unit. Series MUST organize episodes by season.
    Users MUST manually mark numbered units completed, including gaps and
    out-of-order consumption. External catalog lookup is outside this feature.
    (CF12, approved: Unit numbers are positive whole numbers. Progress counts
    distinct completed units; recording the same unit again does not increase
    completion. Repeated consumption remains visible in logs. Totals are
    optional until known, and cannot be reduced below recorded completion.)
19. **REQ-CFL-019 — Workouts:** Gym and Calisthenics tasks MUST support a reusable
    routine copied into each session, session-specific exercise adjustments,
    sets, repetitions, weight where relevant, and duration. Routine edits MUST
    affect future sessions without changing recorded workouts.
    (CF13, approved: A set records an exercise name, positive whole-number
    repetitions, and optional nonnegative weight. Duration uses the shared
    duration control. Initial numeric summaries are total repetitions, highest
    recorded weight per exercise/unit, and total session duration; no estimated
    calories or one-repetition maximum is inferred.)
20. **REQ-CFL-020 — Study and work:** Study and Work tasks MUST support session
    duration and notes.
21. **REQ-CFL-021 — Cleaning:** Cleaning tasks MUST support an item checklist,
    session duration, and notes. (CF14, approved: Checklist definitions belong
    to setup; each session begins with unchecked items. Session checklist
    progress is independent of existing occurrence subtasks and parent
    completion. Historical logs retain their checklist definitions and states.)
22. **REQ-CFL-022 — Duration:** Duration fields MUST support start/stop timers
    and manual entry. At most one timer MUST run across the application. A
    running timer MUST survive closing and reopening the application. Users
    MUST be able to correct its recorded duration. (CF15, approved: Elapsed
    time includes time while the application is closed; pause is not included
    initially. Starting another timer requires stopping or discarding the
    current one explicitly. Stopping populates a draft session; saving the log
    is explicit. Clock changes must not yield negative saved durations.)

### Targets and task lifecycle

23. **REQ-CFL-023 — Finish date:** A task MAY have a desired finish date separate
    from occurrence scheduling. Where a main additive metric and known total
    exist, details MUST show remaining progress and a suggested daily pace.
    Missing the date MUST NOT automatically mark failure or completion.
    (CF16, approved: Pace divides remaining progress by calendar days from
    today through the target date inclusive, rounding whole-unit counts upward.
    An overdue target shows remaining progress and overdue guidance without
    dividing by zero or extrapolating a negative pace.)
24. **REQ-CFL-024 — Finish and reopen:** An explicit Finish task action MUST
    stop future occurrences while preserving history. Reopening MUST be
    possible. Reaching a known last page or episode MAY suggest finishing but
    MUST NOT finish automatically. (CF17, approved: Finishing retains today's,
    past, completed, and explicitly moved/deleted occurrences, removes untouched
    pending future occurrences, and prevents new ones. Reopening resumes the
    preserved schedule from the current local date without filling the closed
    interval. Finished tasks remain accessible through a Finished view.)

### Safety and presentation

25. **REQ-CFL-025 — Durable changes:** Configuration, setup values, logs, timer
    state, hidden types, dismissed notices, and lifecycle changes MUST survive
    restart. Each save MUST be all-or-nothing. Failure MUST retain the draft,
    show a safe error, and permit retry without duplicate logs or partial data.
26. **REQ-CFL-026 — Concurrency and history:** Stale edits MUST NOT overwrite
    newer task, schema, or log changes. The user MUST receive a conflict message
    with a reload path. Type changes and ordinary occurrence operations MUST
    NOT erase task-level activity history.
27. **REQ-CFL-027 — Accessibility and language:** All feature-owned controls,
    validation, summaries, units supplied by the application, and notices MUST
    support en-US and pt-BR, keyboard access, screen readers, enlarged text, and
    the canonical design reference. Charts MUST have readable textual
    equivalents. User-authored labels and units MUST NOT be auto-translated.
28. **REQ-CFL-028 — Local collaboration boundary:** Existing participant links
    MUST survive these changes. The feature MUST NOT imply remote sharing,
    invitations, authentication, or synchronized metrics. [ASSUMPTION CF18:
    Logs measure activity for the local task, with no per-participant attribution
    or permissions until a separate collaboration feature defines them.]

## Business rules

- Type, field, and log identity MUST be independent of display labels. Renaming
  MUST NOT reassign values to a different field or combine unrelated metrics.
- Task-level setup values belong to the task definition; activity values belong
  to individual logs. Occurrence completion remains a separate state.
- Immutable recorded field definitions MUST preserve historical interpretation.
  A compatible field identity may summarize across label changes; different
  kinds or units MUST remain separate metrics.
- Domain validation owns value compatibility, required fields, valid targets,
  structured entries, and progress calculations. Invalid input MUST NOT produce
  a partial configuration, task, or activity record.
- Built-in catalog identities MUST remain stable across translation and upgrade.
  Visibility preferences MUST NOT change the catalog definitions.
- Calendar date targets and schedules MUST remain distinct from recorded session
  instants and elapsed durations.

## Edge cases

| Situation | Expected behavior |
| --- | --- |
| Existing installation upgrades | Preserve tasks and occurrences; assign General and install defaults once. |
| Built-in type is hidden while in use | Existing tasks retain working detail and logging forms. |
| Custom field is retired | Exclude it from new forms and retain recorded history. |
| Number unit or field kind changes | Create a replacement; never reinterpret earlier measurements. |
| Backdated book entry or correction changes subsequent progress | Recalculate from ordered entries; reject an invalid sequence without partial writes. |
| Same comic unit or episode is logged twice | Preserve session history; do not double-count unique completion. |
| Type changes after sessions exist | Keep earlier forms and metrics readable; use new forms for future sessions. |
| Target has passed or total is unknown | Show remaining/empty guidance; no fabricated pace or automatic failure. |
| App closes with a timer running | Restore the active timer and elapsed time on reopening. |
| Save fails or a stale edit is submitted | Preserve the draft and stored history; show retry or reload guidance. |
| Occurrence is completed, moved, deleted, or restored | Keep task-level logs and metrics unchanged. |

## Acceptance criteria

1. **AC-CFL-001:** Given an existing installation, when upgrading and restarting
   twice, then existing task data is preserved, each task uses General, and each
   default type exists once.
2. **AC-CFL-002:** Given a Book task, when opening setup and then recording a
   session, then the book icon and task fields appear in setup and session
   fields appear in logging, without changing occurrence completion.
3. **AC-CFL-003:** Given a built-in type, when managing types, then editing its
   definition is unavailable but hiding/restoring it changes picker visibility
   without altering tasks that use it.
4. **AC-CFL-004:** Given a custom type with each basic field kind and fields in
   both scopes, when saving and reopening setup and session forms, then the
   corresponding typed values persist in their respective scopes.
5. **AC-CFL-005:** Given invalid required, numeric, choice, or structured values,
   when saving, then field guidance appears, valid draft values remain, and
   no partial record is persisted.
6. **AC-CFL-006:** Given logs with numeric values 0, 10, and 20 in chronological
   order, when selecting total/latest/average/highest, then summaries are
   30/20/10/20 and the chart and its text equivalent reflect those entries.
7. **AC-CFL-007:** Given several sessions on one day and a past session, when
   editing or deleting an entry, then history and derived metrics update after
   restart while occurrence completion is unchanged.
8. **AC-CFL-008:** Given a book starting at page 40, when logging page 60 and
   then page 75, then new reading totals 35 pages, not 75; inserting a valid
   intermediate session recalculates the deltas without changing that total.
9. **AC-CFL-009:** Given completed episodes with gaps, when logging an earlier
   episode and then a duplicate, then unique progress increases only for the
   newly completed episode and both sessions remain in history.
10. **AC-CFL-010:** Given a workout routine, when changing it after a recorded
    session, then the old session retains its exercises and sets and the next
    session begins with the new routine.
11. **AC-CFL-011:** Given a custom structured field, when creating exercises,
    episodes, or checklist entries, then its predefined controls save and
    reopen those values without requiring a built-in task type.
12. **AC-CFL-012:** Given a running timer, when closing and reopening the app,
    then the same timer is restored; starting another requires an explicit
    resolution and saving a corrected duration preserves that correction.
13. **AC-CFL-013:** Given a custom field with historical values, when renaming,
    retiring, or replacing its kind/unit, then old logs retain their original
    interpretation and incompatible summaries are not combined.
14. **AC-CFL-014:** Given a task with recorded sessions, when confirming a type
    change, then new sessions use the new type while historical sessions remain
    readable using their recorded forms.
15. **AC-CFL-015:** Given 240 pages remaining and 20 eligible calendar days,
    when viewing a desired finish date, then the suggested pace is 12 pages per
    day; an overdue date does not cause automatic completion or failure.
16. **AC-CFL-016:** Given a recurring task, when finishing and reopening it,
    then protected occurrences and logs remain and recurrence resumes without
    generating occurrences for the closed interval.
17. **AC-CFL-017:** Given a new built-in type added by an upgrade, when dismissing
    its notice and restarting, then the type remains available and its notice
    does not reappear.
18. **AC-CFL-018:** Given a failed write or stale revision, when saving a log,
    schema, or setup change, then no partial data is stored and retry/reload
    retains safe access to the user's draft and existing history.
19. **AC-CFL-019:** Given compact and wide layouts in en-US and pt-BR, when using
    enlarged text, keyboard navigation, and a screen reader, then forms, errors,
    progress values, and actions remain accessible without overflow or
    chart-only information.

## Review boundary

CF01–CF18 were accepted with specification approval. The plan and task checklist
record implementation and validation of the approved behavior.
Custom-type deletion, external catalogs, cross-task dashboards, online accounts,
and remote synchronization are outside this proposed scope.

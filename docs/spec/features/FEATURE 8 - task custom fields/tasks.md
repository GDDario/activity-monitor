# SECTION 3: TASKS

Read the constitution, architecture, conventions, ADR 0001, design reference,
and this feature's approved spec and plan before production changes.
Follow failing test → minimum implementation → refactor throughout.

## Task 1: Domain fields, snapshots, and metrics

**What to build:** Reject invalid definitions and values; preserve immutable history; calculate summaries and progress.
**Files likely affected:** Domain/data/UI tracking files, corresponding tests, and existing task integration points.
**Acceptance criteria:** Reject invalid definitions and values; preserve immutable history; calculate summaries and progress.
**Dependencies:** none

- [x] Write domain validation and progress tests and confirm expected failures.
- [x] Implement field/type/setup/log models and calculation rules; pass domain tests.
- [x] Refactor and verify book baselines, unique episodes, structured fields, and pace edge cases.

## Task 2: Persistence and catalog

**What to build:** Add migration 0008, durable defaults, transactions, logs and timers.
**Files likely affected:** Domain/data/UI tracking files, corresponding tests, and existing task integration points.
**Acceptance criteria:** Add migration 0008, durable defaults, transactions, logs and timers.
**Dependencies:** Task 1

- [x] Write real SQLite upgrade/restart/conflict tests and confirm expected failures.
- [x] Implement migration, codecs, service worker and repository with atomic saves.
- [x] Verify immutable defaults, visibility/notices, type evolution, stale writes and timer recovery.

## Task 3: Task integration and lifecycle

**What to build:** Save setup atomically through the existing task workflow and support finish/reopen.
**Files likely affected:** Domain/data/UI tracking files, corresponding tests, and existing task integration points.
**Acceptance criteria:** Save setup atomically through the existing task workflow and support finish/reopen.
**Dependencies:** Task 2

- [x] Write task integration and recurrence lifecycle regression tests; confirm expected failures.
- [x] Integrate tracking snapshots into task models, mapping, saves and recurrence expansion.
- [x] Verify existing metadata/participants and protected occurrences survive changes.

## Task 4: Generated forms and tracking screens

**What to build:** Expose task types, setup, logging, metrics, management and Finished tasks.
**Files likely affected:** Domain/data/UI tracking files, corresponding tests, and existing task integration points.
**Acceptance criteria:** Expose task types, setup, logging, metrics, management and Finished tasks.
**Dependencies:** Task 3

- [x] Write widget/view-model behavior tests for generated forms and workflows; confirm expected failures.
- [x] Implement localized forms, type configuration, task details, logs, charts, timers and navigation.
- [x] Verify keyboard/large text layouts, safe errors, dirty drafts and history editing.

## Task 5: Validation and delivery

**What to build:** Validate the complete feature and deliver the requested PR.
**Files likely affected:** Domain/data/UI tracking files, corresponding tests, and existing task integration points.
**Acceptance criteria:** Validate the complete feature and deliver the requested PR.
**Dependencies:** Task 4

- [x] Run dart format, flutter analyze, and the full flutter test suite.
- [x] Compare rendered compact/wide/enlarged-text screens against the design references.
- [x] Review acceptance coverage and synchronize documentation with verified behavior.
- [x] Prepare the verified branch and PR description for the requested commit, push, PR, and merge; GitHub history records delivery outcomes.

## Review checkpoint

Verify all approved acceptance scenarios, persistence across restart, and compact/enlarged text layouts before delivery.

## Assumptions to review

- Assumption: CF01: “Implement the custom fields” includes the accepted supporting task-type, logging, metrics, structured-field, timer, and finish-task workflows in this specification, rather than only basic fields in the task editor.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF02: General cannot be hidden because it is the fallback for untyped and existing tasks.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF03: Initial installation is silent; later catalog additions are announced once per installation, including types hidden afterward.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF04: Type and heading names are trimmed, nonblank, limited to 64 characters, and unique ignoring case within their respective collections; custom types cannot reuse a built-in type name. Users choose icons from an accessible supplied set rather than uploading images.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF05: Fields may be reordered and marked required; labels are trimmed, nonblank, unique within a type ignoring case, and at most 64 characters. A type has at most 30 active fields, text values at most 10,000 characters, and choice fields 1–50 distinct nonblank options of at most 100 characters each.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF06: Signed decimal values are supported for generic numbers; units are display labels of at most 32 characters and are never automatically converted. Domain-specific counts and durations have their own nonnegative or positive constraints.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF07: Historical log edits continue to use that log's recorded field definitions. Existing task setup values remain readable; new required fields must be supplied on the next explicit setup save, without blocking unrelated occurrence actions.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF08: Switching types does not copy values by matching labels; previous setup values remain readable as history and new setup values are entered explicitly.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF09: Future session timestamps are rejected; session ordering uses recorded instants, with stable identity as a tie-breaker. Logs belong to the task and may optionally reference the occurrence from which they were opened, without requiring an occurrence for every session.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF11: An explicit starting page, defaulting to zero, establishes the baseline during setup. Current pages are whole numbers within zero and total pages and cannot decrease chronologically; corrections that violate that sequence are rejected with guidance. Separate rereading entries record additional pages without advancing the current page or the completion percentage.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF12: Unit numbers are positive whole numbers. Progress counts distinct completed units; recording the same unit again does not increase completion. Repeated consumption remains visible in logs. Totals are optional until known, and cannot be reduced below recorded completion.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF13: A set records an exercise name, positive whole-number repetitions, and optional nonnegative weight. Duration uses the shared duration control. Initial numeric summaries are total repetitions, highest recorded weight per exercise/unit, and total session duration; no estimated calories or one-repetition maximum is inferred.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF14: Checklist definitions belong to setup; each session begins with unchecked items. Session checklist progress is independent of existing occurrence subtasks and parent completion. Historical logs retain their checklist definitions and states.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF15: Elapsed time includes time while the application is closed; pause is not included initially. Starting another timer requires stopping or discarding the current one explicitly. Stopping populates a draft session; saving the log is explicit. Clock changes must not yield negative saved durations.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF16: Pace divides remaining progress by calendar days from today through the target date inclusive, rounding whole-unit counts upward. An overdue target shows remaining progress and overdue guidance without dividing by zero or extrapolating a negative pace.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.

- Assumption: CF17: Finishing retains today's, past, completed, and explicitly moved/deleted occurrences, removes untouched pending future occurrences, and prevents new ones. Reopening resumes the preserved schedule from the current local date without filling the closed interval. Finished tasks remain accessible through a Finished view.
  Assumption answer: Approved by the user with the specification; no further spec-writer gates requested.


## Validation notes

- Red runs recorded missing domain/storage/form behavior before implementation.
  Additional regressions reproduced stale timer deletion, historical book-bound
  validation after a type change, and accidental translation of custom units.
- Domain, SQLite, task integration, and responsive presentation checks cover
  catalog upgrades, field replacement, restart persistence, progress corrections,
  unique units, timer recovery, and compact/wide/enlarged Portuguese layouts.
- A keyboard-inset regression reproduced compact enlarged-text overflow and
  passed after removing duplicate inset handling.
- Android debug APK built and launched successfully. The emulator subsequently
  went offline, preventing a later debugger reattachment/hot reload. Rendered
  compact/wide tracking captures are in `.scratches/custom-fields-detail-390.png`
  and `.scratches/custom-fields-detail-1000.png`; native Home capture is
  `.scratches/custom-fields-android-home.png`. Local fonts are loaded only when
  available for review images; assertions do not depend on host fonts. Some
  button text retains the widget runner's test-font placeholders, so captures
  establish layout rather than exact native font rendering.
- The installed Flutter preview SDK reports Material library deprecations across
  existing code and two pre-existing initializing-formal suggestions. Analysis
  is checked with `--no-fatal-infos`; errors/warnings remain fatal. These SDK
  notices are not suppressed in project configuration.

### Final results

- `dart format .`: passed (243 files checked).
- Full `flutter test --no-pub --reporter failures-only`: **513 passed, 0 failed**.
  Machine-readable evidence: `.scratches/custom-fields-final-tests.json`.
- `flutter analyze --no-pub --no-fatal-infos`: passed with no errors or warnings.
  Remaining 88 informational notices are Material library deprecations from the
  installed preview SDK (including imports following the existing project
  convention) and two existing initializing-formal suggestions. Default
  `flutter analyze` treats these informational notices as fatal; it is not
  represented as a clean default-mode analysis run.
- The task-type manager, session form, and task-detail screens passed compact,
  wide, enlarged Portuguese text, and open-keyboard checks. Visual additions reuse the existing
  palette and editorial headings; there is no supplied exact mockup for the new
  metrics and type-configuration controls.

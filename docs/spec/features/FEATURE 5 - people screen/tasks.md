# SECTION 3: TASKS

> Delivery update (2026-11-18): after local validation, the user explicitly
> authorized committing and pushing each feature on its own issue branch. Earlier
> local-only restrictions below describe the implementation phase. People is
> delivered on `feature/8-people-screen`, based on `feature/7-home-screen`.
> Issue/project/PR mutations remain outside this authorization.

Read the approved [spec](spec.md), [plan](plan.md), constitution, architecture, conventions, SQLite ADR, design reference and app/AGENTS.md before implementation. Follow failing test → minimum implementation → refactor for each behavior. All work remains local; no commits, pushes or GitHub mutations. Preserve the user lockfile.

## Task 1: Person invariants and directory projection

**What to build:** Name/role bounds, normalization, AND filtering, frequency, real counts and zero-day feedback.
**Files likely affected:** Domain models/value objects and build_people_directory use case.
**Acceptance criteria:** Spec acceptance criteria relevant to this task pass without changing existing guarantees.
**Dependencies:** none

- [x] Write behavior tests for the listed acceptance cases and observe expected failures.
- [x] Implement minimum behavior and verify the new tests pass.
- [x] Refactor preserving behavior and run relevant regression checks.

- [x] Verify blank/overlong Unicode name and role boundaries.
- [x] Verify accent/role/category search, AND filters, stable name ties and zero denominator.

## Task 2: Additive metadata migration and durable repository

**What to build:** Fresh/v4 upgrade, atomic person/category writes, stale rejection, snapshot metrics and paged saved history.
**Files likely affected:** Migration0005, people database worker, repository and SQLite tests.
**Acceptance criteria:** Spec acceptance criteria relevant to this task pass without changing existing guarantees.
**Dependencies:** Task 1

- [x] Write behavior tests for the listed acceptance cases and observe expected failures.
- [x] Implement minimum behavior and verify the new tests pass.
- [x] Refactor preserving behavior and run relevant regression checks.

- [x] Verify v4 upgrade retains legacy long names and participant links.
- [x] Verify failed migration rolls back metadata columns and version.
- [x] Verify durable metadata, duplicate create identity and stale writes.
- [x] Verify 24-entry ordering/pages and 2,001-entry bounded history with participant index use.

## Task 3: Task participant assignment

**What to build:** Preserved default membership, explicit selection, atomic existence/revision checks and task-wide semantics.
**Files likely affected:** Tasks specification, task draft/save/transport/SQL and editor state.
**Acceptance criteria:** Spec acceptance criteria relevant to this task pass without changing existing guarantees.
**Dependencies:** Task 2

- [x] Write behavior tests for the listed acceptance cases and observe expected failures.
- [x] Implement minimum behavior and verify the new tests pass.
- [x] Refactor preserving behavior and run relevant regression checks.

- [x] Verify missing participant causes full task-save rollback.
- [x] Verify removing membership increments revision and stale reassignment fails.
- [x] Verify failed choices preserve selected membership.

## Task 4: People state and composition

**What to build:** Retained queries, guards, retry, change invalidation, history paging and clock lifecycle.
**Files likely affected:** People ViewModels and dependency providers.
**Acceptance criteria:** Spec acceptance criteria relevant to this task pass without changing existing guarantees.
**Dependencies:** Task 3

- [x] Write behavior tests for the listed acceptance cases and observe expected failures.
- [x] Implement minimum behavior and verify the new tests pass.
- [x] Refactor preserving behavior and run relevant regression checks.

- [x] Verify newer responses win, midnight-crossing reads reload, and resume refreshes.
- [x] Verify failed editor saves retain input and invalid saves do not reach storage.

## Task 5: Directory and person flows

**What to build:** Localized Stitch directory, create/edit sheets, sortable/paged history and task/Undo reuse.
**Files likely affected:** People views/widgets/localizations and task companion selector.
**Acceptance criteria:** Spec acceptance criteria relevant to this task pass without changing existing guarantees.
**Dependencies:** Task 4

- [x] Write behavior tests for the listed acceptance cases and observe expected failures.
- [x] Implement minimum behavior and verify the new tests pass.
- [x] Refactor preserving behavior and run relevant regression checks.

- [x] Verify person create/edit/category save and dirty cancellation through UI controls.
- [x] Verify keyboard Tab traversal reveals the final horizontal category filter.
- [x] Verify named-target and Android target-size guidelines in both locales at 320px doubled text.
- [x] Verify history Next and sort-reset controls through UI.
- [x] Fix and verify chip contrast and Solo/Collaborative segment alignment regressions.

## Task 6: Workflow and visual validation

**What to build:** SQLite end-to-end, locale/accessibility/keyboard, fresh screenshots against Stitch, full suite/analyzer/APK.
**Files likely affected:** Tests, capture fixtures and .scratches/people-validation artifacts.
**Acceptance criteria:** Spec acceptance criteria relevant to this task pass without changing existing guarantees.
**Dependencies:** Task 5

- [x] Write behavior tests for the listed acceptance cases and observe expected failures.
- [x] Implement minimum behavior and verify the new tests pass.
- [x] Refactor preserving behavior and run relevant regression checks.
- [x] Run full format, analyzer and test suite; inspect logs.
- [x] Build Android debug APK and inspect native keyboard/layout.
- [x] Capture both locales and reference/compact/wide/320px doubled-text states; compare images and HTML.
- [x] Map AC-PEO-001–015 to fresh evidence and verify lockfile preservation.

## Review checkpoint

Verify real metadata/links survive reopening, all history and counts follow the approved date rules, and rendered states match Stitch before declaring complete. Continue implementation directly after checklist creation as instructed.

## Assumptions to review

- Assumption: PEO01, as described in the spec/plan.
  Assumption answer: Proceed with the proposed choice under the user instruction “Continue, dont stop.”
- Assumption: PEO02, as described in the spec/plan.
  Assumption answer: Proceed with the proposed choice under the user instruction “Continue, dont stop.”
- Assumption: PEO03, as described in the spec/plan.
  Assumption answer: Proceed with the proposed choice under the user instruction “Continue, dont stop.”
- Assumption: PEO04, as described in the spec/plan.
  Assumption answer: Proceed with the proposed choice under the user instruction “Continue, dont stop.”
- Assumption: PEO05, as described in the spec/plan.
  Assumption answer: Proceed with the proposed choice under the user instruction “Continue, dont stop.”
- Assumption: PEO06, as described in the spec/plan.
  Assumption answer: Proceed with the proposed choice under the user instruction “Continue, dont stop.”
- Assumption: PEO07, as described in the spec/plan.
  Assumption answer: Proceed with the proposed choice under the user instruction “Continue, dont stop.”
- Assumption: PP01, as described in the spec/plan.
  Assumption answer: Proceed with the proposed choice under the user instruction “Continue, dont stop.”
- Assumption: PP02, as described in the spec/plan.
  Assumption answer: Proceed with the proposed choice under the user instruction “Continue, dont stop.”

## Completion and evidence

Local implementation and validation complete. Issue #8 and project status remain
unchanged; no commit, push, issue/PR operation or other GitHub mutation occurred.
The existing branch remains `feature/7-home-screen` with reviewable working-tree
changes. The user's original `app/pubspec.lock` is byte-identical to the saved
preimplementation snapshot and was not replaced. Existing generated Android
artifacts were left alone.

Fresh run: `.scratches/people-validation/20261118-121436/`, produced by
`bash .scratches/recheck-people.sh`:

- Format verification PASS.
- Analysis PASS with `--no-fatal-infos`: 59 infos, no errors or warnings: 56 SDK deprecations and three preexisting
  Home style notices in untouched files. New style findings were fixed. The SDK
  deprecates Material imports and GlobalMaterialLocalizations; no unrelated
  framework migration was introduced.
- Full suite: **409 tests passed**, including extended person edit/cancel,
  explicit Android target-size/named-target accessibility guidelines and
  horizontal filter keyboard traversal. The six-test `accessibility.log` also
  records those focused presentation checks.
- **112 fresh screenshots**, eight locale/layout combinations (en-US and pt-BR;
  390×844, reference 585×1500, wide 1200×900, 320×800 doubled text), covering
  populated/scrolled directory, empty, filtered, loading, unavailable,
  create/edit, history, participant choices and keyboard/action visibility.
  Reviewed all via contact sheets and detailed images against Stitch HTML/image.
  The final run's 104 non-history images are byte-identical to the reviewed set;
  all eight changed history images were inspected individually after the final
  sort-chip contrast and Portuguese heading fixes. The subsequent final style-only
  cleanup produced 112 byte-identical captures (`visual-comparison.json`).
- Android debug APK PASS; existing future Built-in Kotlin migration notice
  remains visible in `apk.log`.
- Native startup on emulator-5554 applied migration 0005 to the existing
  database without reset. `native-people-final.png` and
  `native-create-keyboard.png` verify the real directory and keyboard layout.
  The blank editor was dismissed without saving; all new workflow data was
  confined to disposable test databases.
- Lockfile preservation PASS and `git diff --check` PASS.

Red/Green logs are in `.scratches/people-validation/`: domain, storage, assignment,
state, selector, visual contrast/bar and history contrast regressions. Tests
verify the failed conditions before the corresponding fixes. Final contrast
checks cover selected/unselected history controls and person categories.

### Acceptance mapping

| Criterion | Verified evidence |
| --- | --- |
| AC-PEO-001 | `people_repository_test`, `people_migration_test`, directory widget and native screenshot. |
| AC-PEO-002 | Repository reopen/stale-write tests and extended create/edit UI scenario. |
| AC-PEO-003 | Domain validation, rejected saves, and dirty Cancel/discard UI scenario. |
| AC-PEO-004 | Directory projection role/accent/localized-category tests and search widget test. |
| AC-PEO-005 | Three-completion projection threshold and real-history 30-day boundary counts. |
| AC-PEO-006 | Multi-person history fixture counts 21 shared occurrences once globally; proportions tests. |
| AC-PEO-007 | Zero denominator projection and both-locale empty captures. |
| AC-PEO-008 | 24-occurrence stable paging, 2,001-occurrence bounded/indexed history, UI Next/sort reset. |
| AC-PEO-009 | Repository fixture excludes future/deleted completions and workflow excludes reopened completion. |
| AC-PEO-010 | Real assignment save/load/removal/stale rejection; established shared Task changes feed Home/Calendar and People composition. |
| AC-PEO-011 | Real SQLite complete/reopen/postpone/delete/Undo/reopen workflow plus reused TaskCard and shared Undo. |
| AC-PEO-012 | Unavailable repository/state tests, atomic missing-person rollback, stale response tests and retry states. |
| AC-PEO-013 | Retained query/filter, crossing-midnight reload, resume tests and directory preservation during refresh. |
| AC-PEO-014 | Both-locale compact doubled-text widget tests with named/minimum-size target guidelines, 112 captures and native keyboard review. |
| AC-PEO-015 | v4 upgrade/rollback tests, legacy identity/link preservation and storage reopening with no remote dependency. |

### Design adaptations and implementation decisions

The existing shared header and Today/People/Calendar/Profile navigation remain,
so New Person occupies its own reachable row. Initials replace unsaved portrait
assets; no presence/focus badges or notification preferences are fabricated.
Cards add real last-activity information. Wide layouts use the existing shell;
large text stacks metrics and wraps chips. Create/edit includes the approved
optional role/category fields and uses keyboard-aware sheets. History reuses
existing task cards/actions and a readable primary-colored sort selection.

Reuse existing participant string identity and validate person input in the
shared domain draft rather than introducing parallel ID/name wrappers and a
pass-through save use case. These structural simplifications preserve the
approved behavior. Person metadata uses additive migration 0005; participant
membership remains task-wide and atomic with task saving. No dependency changes
or remote collaboration/notification/photo behavior were added.


## Branch separation verification

The People-only branch was reconstructed before committing, excluding Profile,
its migration, preferences, dependencies and theme changes. Fresh format, analysis
and full-suite results are in `.scratches/branch-organization/people-*.log`.
The user's preexisting lockfile edits remain unstaged.

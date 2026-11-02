# SECTION 3: TASKS

Read constitution, architecture, conventions, design reference, ADR 0001 and this feature spec before implementation. Follow failing test → minimum implementation → refactor for each behavior; synchronize the spec first if behavior changes.

## Task 1: Calendar persistence
**What to build:** Durable constrained entries and participants, versioned migration and repository with unavailable state.
**Files likely affected:** app/lib/data, app/lib/domain, app/lib/app/dependencies, app/test.
**Acceptance criteria:** Fresh SQLite opens with version 1, constraints are enforced, persisted entries and participants can be read, failures are safe.
**Dependencies:** none.
- [ ] Write failing real SQLite migration, constraints and read tests.
- [ ] Implement database lifecycle, migration and repository; verify tests pass.
- [ ] Refactor and validate data integrity and safe failure handling.
- [x] Verify an in-memory migration creates tables, enforces cadence and foreign keys, and preserves records when run again.
- [x] Verify repository reads stored entries and participant links.

## Task 2: Calendar state and filtering
**What to build:** Date selection, month/week movement and cadence/participant filtering.
**Files likely affected:** app/lib/ui/calendar/view_models, app/test.
**Acceptance criteria:** Month clamping, leap years, week boundaries, selection and filter intersection follow the spec.
**Dependencies:** Task 1.
- [ ] Write failing state tests for navigation, mode, boundaries and filters.
- [ ] Implement state and verify tests pass.
- [ ] Refactor and validate acceptance criteria.
- [x] Verify leap-year month clamping, week movement, a month grid spanning years, and cadence/participant intersection.

## Task 3: Calendar presentation
**What to build:** Responsive localized Stitch-inspired calendar, legend, filter chips, selected-date results and accessible controls.
**Files likely affected:** app/lib/ui/calendar, app/test.
**Acceptance criteria:** Both locales, selected states, empty/unavailable states, keyboard focus and compact/wide layouts are usable.
**Dependencies:** Tasks 1 and 2.
- [ ] Write failing widget tests for navigation, filters, states, localization and responsive layout.
- [ ] Implement presentation and verify tests pass.
- [ ] Refactor and compare against Stitch image, HTML and design reference.
- [x] Verify that the mode selector switches to week navigation and that a cadence filter changes the selected-date entries.

## Task 4: Final verification
**What to build:** Validate the feature and synchronize documentation.
**Files likely affected:** app, feature documents.
**Acceptance criteria:** All feature criteria, existing tests and quality gates pass.
**Dependencies:** Tasks 1–3.
- [ ] Verify accessibility, both locales and enlarged text at compact and wide sizes.
- [ ] Run dart format ., flutter analyze and flutter test from app.
- [ ] Verify every acceptance criterion and record remaining blockers.

## Task 5: Startup database initialization and migrations
**What to build:** Initialize native SQLite at app startup, apply ordered migrations safely, and document a development reset.
**Files likely affected:** app/lib/app, app/lib/data/services, app/test, app/README.md.
**Acceptance criteria:** First boot creates a versioned database; reopening preserves records; failed and unsupported migrations do not erase data; calendar reports initialization failure as unavailable.
**Dependencies:** Task 1.
- [x] Write failing tests for startup initialization without calendar navigation and propagation of initialization failures.
- [x] Write failing SQLite tests for fresh creation, reopening, unsupported versions and transactional migration failure.
- [x] Implement eager startup initialization and ordered transactional migrations; pass the tests.
- [x] Document development database location and a safe, explicit recreation procedure.
- [x] Run dart format ., flutter analyze, and flutter test; verify the acceptance criteria with automated tests.

## Task 6: Migration history and one-time calendar seed
**What to build:** Record versioned migrations and atomically run an injected example seeder for the current local month on fresh and existing version-1 databases.
**Files likely affected:** app/lib/data/services/database, app/test, app/README.md.
**Acceptance criteria:** Examples are labeled, include today, different cadences and participants; history prevents repeats; legacy data is preserved; failures roll back seed and history.
**Dependencies:** Task 5.
- [x] Write failing tests for fresh and legacy migration history, seeder execution, reopens and next-month behavior.
- [x] Write failing tests for seeder rollback, UUIDv7 generation, invalid history and date boundaries.
- [x] Implement transactional migration history and injected calendar seeder; pass the tests.
- [x] Document example data, migration tracking and recreation behavior.
- [x] Run dart format ., flutter analyze and flutter test; verify criteria and update this checklist.

## Task 7: Numbered migration files and classes
**What to build:** Put each registered migration in a separate numbered file and numbered class under the migrations directory, preserving applied migration identifiers.
**Files likely affected:** app/lib/data/services/database, app/test, docs/spec/project/conventions.md, app/README.md.
**Acceptance criteria:** Filenames and classes contain matching sortable numbers; existing migration history and seed-once behavior remain compatible.
**Dependencies:** Task 6.
- [x] Write a failing test for the numbered registered migrations and their persisted identifiers.
- [x] Extract numbered migration classes and verify fresh and existing databases and seed-once behavior.
- [x] Document the naming convention and run dart format ., flutter analyze, and flutter test.

## Task 8: Startup verification and readable calendar indicators
**What to build:** Verify the application root initializes and seeds a real database before calendar navigation, and use legible circular solo/collaborative indicators with a matching legend.
**Files likely affected:** app/test/database_startup_test.dart, app/test/calendar_view_test.dart, app/lib/ui/calendar/views/calendar_view.dart.
**Acceptance criteria:** Startup creates and seeds SQLite without visiting Calendar; indicator shapes, sizes, semantics and legend distinguish categories without relying only on color.
**Dependencies:** Tasks 6 and 7.
- [x] Verify root startup initializes, migrates and seeds a real database without visiting Calendar.
- [x] Write and run failing widget tests for visible, distinguishable indicators and their legend.
- [ ] Implement the indicators, rerun tests, and compare against the available design reference. Blocker: the supplied Stitch files are no longer present, and the widget-test screenshot does not render the production fonts or icons.
- [x] Run dart format ., flutter analyze and flutter test; record visual verification limitations.

Outstanding: complete first-use persistence and failure-path verification on supported platforms; test and verify the remaining navigation, localization, keyboard, semantics, large-text, responsive and filter scenarios; finish comparison and alignment with the Stitch reference. The current implementation and automated checks do not establish feature completeness.

## Assumptions to review
1. Assumption: Entries are local materialized occurrences; recurrence expansion and synchronization are later work. — Impact: HIGH
   Assumption answer: Pending
2. Assumption: One cadence and at most one participant combine with AND; All Cadences resets cadence and tapping an active participant clears it. — Impact: MEDIUM
   Assumption answer: Pending
3. Assumption: Native storage uses an application-support directory and web storage is unavailable. — Impact: HIGH
   Assumption answer: Pending
4. Assumption: Single local user, with no remote authorization or encryption in this issue. — Impact: HIGH
   Assumption answer: Pending
5. Assumption: Calendar entries have id, title, local date, cadence and participant links; participants have id and display name. — Impact: MEDIUM
   Assumption answer: Pending
6. Assumption: Weeks begin Sunday in both supported locales. — Impact: LOW
   Assumption answer: Pending
7. Assumption: Explicitly requested example entries are installed on existing and new databases, including release builds, and are labeled as examples. — Impact: HIGH
   Assumption answer: Pending

## Review checkpoint
Verify assumptions, screen against Stitch, data semantics and every acceptance criterion before handoff.

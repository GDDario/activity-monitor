# SECTION 3: TASKS

## Task 1: Establish the visual foundation

**What to build:** Read `docs/spec/project/constitution.md`, `docs/spec/project/architecture.md`, and `docs/spec/project/conventions.md`; read `docs/spec/project/design-reference.md` before UI work. Start with failing widget tests, then create the shared theme, responsive visual primitives, and current Today dashboard preview using reusable components. Refactor after tests pass.
**Files likely affected:** `app/lib/app/activity_monitor_app.dart`, `app/lib/ui/core/`, `app/lib/ui/dashboard/`, `app/test/`
**Acceptance criteria:**
1. Compact and wide Today layouts are calm, bounded, and accessible.
2. Status is conveyed by text or iconography as well as color.
3. `dart format .`, `flutter analyze`, and `flutter test` pass.
**Dependencies:** none

## Task 2: Compose application infrastructure

**What to build:** Read the required project documents. Starting with failing widget and factory tests, compose the router, supported localization, feedback host, and replaceable application dependency scope. Keep the existing Today dashboard visible and introduce no domain or persistence behavior. Refactor after green tests.
**Files likely affected:** `app/lib/app/`, `app/test/`
**Acceptance criteria:**
1. The router opens Today and unknown locations show a safe fallback.
2. The root offers both supported locales and one feedback host.
3. Composition is test-replaceable and all quality gates pass.
**Dependencies:** Task 1

## Task 3: Add base routes and responsive destination shell

**What to build:** Read the required project and design documents. Write failing widget tests for primary destinations, active navigation, and empty states. Implement the minimum responsive shell that retains Today and opens blank People, Calendar, and Profile Views with helpful descriptions. Refactor without changing tested behavior.
**Files likely affected:** `app/lib/app/`, `app/lib/ui/core/widgets/`, `app/lib/ui/*/views/`, `app/test/`
**Acceptance criteria:**
1. Today, People, Calendar, and Profile are reachable and visibly active.
2. Compact and wide layouts preserve every primary destination without overflow.
3. People, Calendar, and Profile show short purpose descriptions without user data; quality gates pass.
**Dependencies:** Task 2

## Task 4: Add the shared title area

**What to build:** Read the required project and design documents. Start with failing widget tests, then add the reusable title area with avatar/abbreviation, screen phrase, Profile and Calendar commands, and safe notifications response. Use presentation defaults only; do not add profile storage or notification behavior. Refactor after green tests.
**Files likely affected:** `app/lib/ui/core/widgets/`, `app/lib/ui/*/views/`, `app/lib/app/`, `app/test/`
**Acceptance criteria:**
1. Each primary View renders an accessible title area with its own phrase.
2. Profile and Calendar access route correctly and notification access is safe.
3. `dart format .`, `flutter analyze`, and `flutter test` pass.
**Dependencies:** Task 3

## Review checkpoint

Verify phone, tablet, and desktop layouts: the existing Today dashboard,
navigation, title areas, and blank destination descriptions must remain calm,
accessible, and aligned with the design reference.

## Assumptions to review

1. [ASSUMPTION: a future feature will introduce SQLite through an approved ADR before any durable user data is created.] — Impact: HIGH
2. [ASSUMPTION: notifications are a non-functional entry point until a notifications feature is specified.] — Impact: MEDIUM
3. [ASSUMPTION: these are the only initial product locales.] — Impact: MEDIUM
4. [ASSUMPTION: existing Riverpod composition remains sufficient and may evolve as application behavior is added.] — Impact: LOW
5. [ASSUMPTION: the foundation has no authentication, authorization, synchronization, or remote-data boundary.] — Impact: HIGH

# SECTION 3: TASKS

## Task 1: Establish the visual foundation

**What to build:** Read the required project documents and design reference. Start with failing widget tests, then create the shared theme, responsive visual primitives, and current Today dashboard preview using reusable components. Refactor after tests pass.
**Files likely affected:** `app/lib/app/activity_monitor_app.dart`, `app/lib/ui/core/`, `app/lib/ui/dashboard/`, `app/test/`
**Acceptance criteria:**
1. Compact and wide Today layouts are calm, bounded, and accessible.
2. Status is conveyed by text or iconography as well as color.
3. `dart format .`, `flutter analyze`, and `flutter test` pass.
**Dependencies:** none

## Task 2: Compose application infrastructure

**What to build:** Starting with failing widget and factory tests, compose the router, supported localization, feedback host, dependency scope, HTTP client factory, and UUIDv7 factory. Keep the existing Today dashboard visible and use no data-backed domain behavior. Refactor after green tests.
**Files likely affected:** `app/lib/app/`, `app/lib/data/services/`, `app/test/`
**Acceptance criteria:**
1. The router opens Today and unknown locations show a safe fallback.
2. The root offers both supported locales and one feedback host.
3. Composition factories are test-replaceable; quality gates pass.
**Dependencies:** Task 1

## Task 3: Add base routes and responsive destination shell

**What to build:** After reading the required documents, write failing widget tests for primary destinations, active navigation, and empty states. Implement the minimum shell that retains Today and opens blank People, Calendar, and Profile Views with helpful descriptions. Refactor without changing tested behavior.
**Files likely affected:** `app/lib/app/`, `app/lib/ui/core/widgets/`, `app/lib/ui/*/views/`, `app/test/`
**Acceptance criteria:**
1. Today, People, Calendar, and Profile are reachable and visibly active.
2. Compact and wide layouts preserve every primary destination without overflow.
3. New empty Views use helpful descriptions; quality gates pass.
**Dependencies:** Task 2

## Task 4: Add the shared title area

**What to build:** Start with failing widget tests, then add the reusable title area with avatar/abbreviation, screen phrase, calendar command, and safe notifications response. Use local presentation defaults only. Refactor after green tests.
**Files likely affected:** `app/lib/ui/core/widgets/`, `app/lib/ui/*/views/`, `app/lib/app/`, `app/test/`
**Acceptance criteria:**
1. Each primary View renders an accessible title area with its own phrase.
2. Calendar access routes correctly and notification access is safe.
3. Quality gates pass.
**Dependencies:** Task 3

## Task 5: Persist daily activities and implement Today actions

**What to build:** Read all required documents before production code. Write failing domain, migration, Use Case, ViewModel, and widget tests, then add activity scheduling models, UUIDv7 IDs, versioned local migrations, repository contracts, and commands for loading, completion, editing, unscheduling, and focus drafts. Implement the minimum activity interactions and refactor.
**Files likely affected:** `app/lib/domain/`, `app/lib/data/`, `app/lib/ui/dashboard/`, `app/lib/ui/focus/`, `app/lib/app/`, `app/test/`
**Acceptance criteria:**
1. Valid activity edits, completion, and one-day unscheduling persist correctly.
2. Daily summary updates and invalid edits/durations persist nothing.
3. Right swipe opens editable focus setup and left swipe requires confirmation; quality gates pass.
**Dependencies:** Task 4

## Task 6: Add People search, sorting, and pagination

**What to build:** Start with failing query, migration, Use Case, ViewModel, and widget tests. Add person/collaboration persistence, bounded repository queries, People state, and search/sort/page controls with collaboration details. Use real local SQLite migration tests; refactor after green tests.
**Files likely affected:** `app/lib/domain/`, `app/lib/data/`, `app/lib/ui/people/`, `app/lib/app/`, `app/test/`
**Acceptance criteria:**
1. Search, initial sort, and page boundaries produce correct results.
2. Results show tags and shared-activity information.
3. Empty/out-of-range results are safe; quality gates pass.
**Dependencies:** Task 5

## Task 7: Add Calendar counts and selected-day navigation

**What to build:** Begin with failing local-day count and route tests. Add bounded calendar-count querying, a full-screen Calendar View, and the selected-day daily route that reuses daily activities. Refactor only after tests pass.
**Files likely affected:** `app/lib/domain/`, `app/lib/data/`, `app/lib/ui/calendar/`, `app/lib/ui/dashboard/`, `app/lib/app/`, `app/test/`
**Acceptance criteria:**
1. Visible days show correct planned-activity counts, including zero.
2. Selecting a day opens that day's daily experience.
3. Queries are range-bounded and quality gates pass.
**Dependencies:** Task 5

## Task 8: Add persistent Profile settings

**What to build:** Start with failing persistence, ViewModel, and widget tests. Add profile preferences, versioned migration, validated local image reference, and controls for name, image, theme, and language. Apply changes at composition boundaries; do not add remote synchronization. Refactor after green tests.
**Files likely affected:** `app/lib/domain/`, `app/lib/data/`, `app/lib/ui/profile/`, `app/lib/ui/core/theme/`, `app/lib/app/`, `app/pubspec.yaml`, `app/test/`
**Acceptance criteria:**
1. Valid profile changes persist and affect presentation.
2. Invalid media preserves the prior image and shows a safe failure.
3. Invalid stored preferences use defaults; quality gates pass.
**Dependencies:** Task 4

## Review checkpoint

Verify phone, tablet, and desktop layouts with empty and populated states: all
navigation, header controls, swipes, selected-day context, People paging, and
profile preferences must remain calm, accessible, and aligned with the design
reference.

## Assumptions to review

1. [ASSUMPTION: local durable persistence is the offline-first single source of truth.] — Impact: HIGH
2. [ASSUMPTION: removal is day-specific.] — Impact: HIGH
3. [ASSUMPTION: a later focus feature owns started-session persistence and timing.] — Impact: HIGH
4. [ASSUMPTION: the initial release has one local profile and no synchronization or authorization boundary.] — Impact: HIGH
5. [ASSUMPTION: existing Riverpod composition remains sufficient.] — Impact: LOW

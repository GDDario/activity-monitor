# SECTION 3: TASKS

Checklist items have not been verified. Existing theme, routes, shell, title
area, and tests should be assessed before changing them. Check off each item
when verified; record blockers alongside incomplete items. For unmet behavior,
write a focused failing test efore implementing the fix; do not force existing
passing behavior to fail.

## Task 1: Establish the visual foundation

**What to build:** Read `docs/spec/project/constitution.md`, `docs/spec/project/architecture.md`, and `docs/spec/project/conventions.md`; read `docs/spec/project/design-reference.md` before UI work. Assess and improve the existing shared theme, responsive visual primitives, and Today dashboard preview using reusable components. Refactor after tests pass.
**Files likely affected:** `app/lib/app/activity_monitor_app.dart`, `app/lib/ui/core/`, `app/lib/ui/dashboard/`, `app/test/`
**Acceptance criteria:**
1. Compact and wide Today layouts are calm, bounded, and accessible.
2. Status is conveyed by text or iconography as well as color.
3. `dart format .`, `flutter analyze`, and `flutter test` pass.
**Dependencies:** none

- [ ] Review existing widget tests and add focused failing tests for any unmet theme, responsive layout, accessibility, or non-color status requirements.
- [ ] Adjust the shared theme and reusable responsive visual primitives where needed.
- [ ] Preserve the existing Today dashboard using shared components; verify the relevant widget tests pass.
- [ ] Refactor and verify compact and wide layouts against the design reference.
- [ ] Run `dart format .`, `flutter analyze`, and `flutter test`.

## Task 2: Compose application infrastructure

**What to build:** Read the required project documents. Assess and complete the existing router, localization, feedback host, and replaceable application dependency scope. Keep the existing Today dashboard visible and introduce no domain or persistence behavior. Refactor after green tests.
**Files likely affected:** `app/lib/app/`, `app/test/`
**Acceptance criteria:**
1. The router opens Today and unknown locations show a safe fallback.
2. The root offers both supported locales and one feedback host.
3. Composition is test-replaceable and all quality gates pass.
**Dependencies:** Task 1

- [ ] Review existing coverage; add focused failing tests for unmet routing, fallback, locale, feedback, and replaceable composition requirements.
- [ ] Compose the router with Today as the initial destination and a safe unknown-route fallback.
- [ ] Provide translated foundation-owned text in both supported locales and verify English fallback for an unsupported locale.
- [ ] Verify there is an accessible presentation-feedback host and safe messages.
- [ ] Provide a replaceable application dependency scope and retain the Today dashboard.
- [ ] Verify tests pass, refactor, and run `dart format .`, `flutter analyze`, and `flutter test`.

## Task 3: Add base routes and responsive destination shell

**What to build:** Read the required project and design documents. Verify primary destinations, active navigation, and empty states. Improve the responsive shell as needed that retains Today and opens blank People, Calendar, and Profile Views with helpful descriptions. Refactor without changing tested behavior.
**Files likely affected:** `app/lib/app/`, `app/lib/ui/core/widgets/`, `app/lib/ui/*/views/`, `app/test/`
**Acceptance criteria:**
1. Today, People, Calendar, and Profile are reachable and visibly active.
2. Compact and wide layouts preserve every primary destination without overflow.
3. People, Calendar, and Profile show short purpose descriptions without user data; quality gates pass.
**Dependencies:** Task 2

- [ ] Add focused failing widget tests for any unmet destination routes, active navigation, responsive layouts, enlarged text, and empty states.
- [ ] Implement the responsive destination shell and active navigation for Today, People, Calendar, and Profile.
- [ ] Add blank People, Calendar, and Profile Views with short purpose descriptions.
- [ ] Verify tests pass and compact and wide layouts show all destinations without overflow.
- [ ] Refactor and run `dart format .`, `flutter analyze`, and `flutter test`.

## Task 4: Add the shared title area

**What to build:** Read the required project and design documents. Assess and complete the reusable title area with avatar/abbreviation, screen phrase, Profile and Calendar commands, and safe notifications response. Use presentation defaults only; do not add profile storage or notification behavior. Refactor after green tests.
**Files likely affected:** `app/lib/ui/core/widgets/`, `app/lib/ui/*/views/`, `app/lib/app/`, `app/test/`
**Acceptance criteria:**
1. Each primary View renders an accessible title area with its own phrase.
2. Profile and Calendar access route correctly and notification access is safe.
3. `dart format .`, `flutter analyze`, and `flutter test` pass.
**Dependencies:** Task 3

- [ ] Add focused failing widget tests for any unmet accessible title areas, screen phrases, avatar fallback, Profile and Calendar navigation, and safe notification access.
- [ ] Implement the reusable title area with avatar or abbreviation and each screen’s phrase.
- [ ] Connect Profile and Calendar commands and provide a safe notification response using presentation defaults.
- [ ] Verify tests pass and title areas satisfy the design reference.
- [ ] Refactor and run `dart format .`, `flutter analyze`, and `flutter test`.

## Review checkpoint

Verify phone, tablet, and desktop layouts, enlarged text, keyboard focus, and
both locales: the existing Today dashboard, navigation, title areas, and blank
destination descriptions must remain accessible and aligned with the design
reference. Confirm all specification criteria and quality gates before completion.

## Assumptions to review

1. Assumption: A future feature will introduce SQLite through an approved ADR before any durable user data is created. — Impact: HIGH
   Assumption answer: Yes.

2. Assumption: Notifications are a non-functional entry point until a notifications feature is specified. — Impact: MEDIUM
   Assumption answer: Yes.

3. Assumption: These are the only initial product locales and unsupported locales fall back to United States English. — Impact: MEDIUM
   Assumption answer: Yes. The locales are `pt-BR` and `en-US`, with `en-US` as the fallback.

4. Assumption: Existing Riverpod composition remains sufficient and may evolve as application behavior is added. — Impact: LOW
   Assumption answer: Yes.

5. Assumption: The foundation has no authentication, authorization, synchronization, or remote-data boundary. — Impact: HIGH
   Assumption answer: Yes. Data models will be modeled by feature.

6. Assumption: A profile name is optional during setup. — Impact: MEDIUM
   Assumption answer: No. A profile name is required for setup and app usage.

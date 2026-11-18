# SECTION 3: TASKS

## Required context and workflow

Read the constitution always, architecture and SQLite ADR for structural/data
changes, conventions before production code, and design reference plus Stitch
Today HTML/image before UI work. Follow root/app AGENTS.md and the approved
[spec](spec.md) and [plan](plan.md). Tests follow Red → Green → Refactor; check
items only after verification. Keep artifacts under `.scratches/`. Preserve the
user's existing lockfile. The user approved continuing through implementation
and validation in this session; no additional checklist approval gate applies.

## Task 1: Pure daily overview and stable ordering

**What to build:** Typed scope, period sections and summary projection over saved occurrences.
**Files likely affected:** domain/models/daily_overview.dart, domain/models/task_ordering.dart, domain/use_cases/build_daily_overview.dart, local_task_repository.dart, test/home_overview_test.dart.
**Acceptance criteria:** Correct eligibility, exclusive scopes, 4/7 → 57%, noon/untimed groups, stable ordering and Next with no writes (AC-HOM-002–007, 013).
**Dependencies:** none.

- [x] Red: test effective-day/deleted exclusion, scope exclusivity/deduplication and missing-companion fallback.
- [x] Red: test empty/all-complete percentages, collaborative occurrence counts and 4/7 summary.
- [x] Red: test noon/period precedence, status/time/title/ID ties and earliest eligible Next.
- [x] Green: implement immutable types and pure calculation; share the existing unchanged domain comparator with the repository.
- [x] Refactor and verify the focused domain tests pass.

## Task 2: ViewModel clock, state and navigation lifetime

**What to build:** One immutable overview snapshot, retained scope, lifecycle-aware minute ticks and safe asynchronous loads.
**Files likely affected:** today_view_model.dart, task_dependencies.dart, test/today_view_model_test.dart, test/task_screen_state_test.dart.
**Acceptance criteria:** Scope survives navigation; minute/filter changes do not read storage; old-day/superseded reads cannot publish; pause/resume/dispose are safe (AC-HOM-001, 003, 006, 011–013).
**Dependencies:** Task 1.

- [x] Red: test companion selection/fallback only on successful load and preservation through failures.
- [x] Red: test same-day minute/resume projection without reads; midnight and old aggregate/streak results; timer pause/dispose.
- [x] Green: integrate projection and clock snapshot, retain provider, wire lifecycle and cancel/rearm one timer.
- [x] Refactor and verify existing Today/Calendar state tests and navigation retention.


## Task 3: Localization and opt-in notes

**What to build:** Home date/greeting/group/summary strings and optional two-line task notes.
**Files likely affected:** home_localizations.dart, activity_monitor_app.dart, task_card.dart, test/home_localizations_test.dart, test/task_card_test.dart.
**Acceptance criteria:** Both locales and greeting boundaries; notes show only on Home without changing task actions (AC-HOM-001, 007, 014).
**Dependencies:** Task 1.

- [x] Red: test en-US/pt-BR greeting boundaries, count plurals, section labels and zero/complete feedback.
- [x] Red: test blank/long notes, two-line preview and existing default card behavior.
- [x] Green: register Home delegate and implement opt-in preview with full saved notes retained in Edit.
- [x] Refactor and verify localization/card regressions.

## Task 4: Stitch Home composition and accessible states

**What to build:** Date/greeting header, exclusive companion scope chips, Rhythm summary and grouped agenda with existing actions.
**Files likely affected:** dashboard_view.dart, dashboard/widgets/, test/home_view_test.dart, test/widget_test.dart, test/today_tasks_view_test.dart.
**Acceptance criteria:** Real summary/sections and scope changes, distinct loading/empty/filter-empty/unavailable states, reachable creation/reset/Undo and navigation (AC-HOM-001–014).
**Dependencies:** Tasks 1–3.

- [x] Red: test localized real summary, sections, Next, companion selection/reset and no fake identities.
- [x] Red: test loading/unavailable/empty distinctions, disabled creation guards, reset and accessible progress.
- [x] Green: compose responsive Home widgets using existing tokens, header actions, editor, TaskCard and Undo.
- [x] Verify 320px/doubled text, both locales, wide layout, keyboard and 48px semantics; refactor after tests pass.

## Task 5: Durable actions and cross-screen integration

**What to build:** Regression coverage for persisted Home updates and retained scope/shared recovery.
**Files likely affected:** test/task_workflow_integration_test.dart, test/home_workflow_test.dart, existing file-backed helpers.
**Acceptance criteria:** Atomic durable task actions update groups/summary, restart preserves records, failed writes are safe, Calendar selection/Undo and Home scope survive navigation (AC-HOM-008–012).
**Dependencies:** Task 4.

- [x] Red/Green: verify creation, edits across period boundaries, complete/reopen, postpone, delete and Undo with real SQLite and reopen storage.
- [x] Verify failed writes/retry do not announce success or replay actions.
- [x] Verify Home→Calendar→Home scope retention and shared remaining Undo window without resetting Calendar selection.
- [x] Refactor and verify existing workflow/persistence regressions.

## Task 6: Fresh visual and runtime validation

**What to build:** Current Home acceptance evidence and any regression fixes revealed by rendering.
**Files likely affected:** temporary screenshot fixture/logs under .scratches/, this checklist.
**Acceptance criteria:** All automated gates and fresh comparison against Stitch pass (AC-HOM-014 and all criteria).
**Dependencies:** Tasks 1–5.

- [x] Run formatting, analysis (retain SDK infos; errors/warnings fatal), full test suite and Android debug build.
- [x] Capture populated/empty/filtered/loading/unavailable/completed Home, both locales, compact/wide/doubled text and editor/Undo overlays.
- [x] Compare fresh renders with Stitch HTML/image; add failing regressions and fix any functionality/visual failures.
- [x] Launch with --print-dtd and verify native rendering, keyboard-safe editor and actions; hot reload/restart meaningful production changes where possible.
- [x] Synchronize acceptance evidence and GitHub #7 with actual results; preserve user lockfile and check local time before any commit/push.


## Review checkpoint

Verify each AC-HOM criterion against fresh automated and rendered evidence before
considering Home complete; the user has authorized proceeding beyond this checklist.

## Assumptions to review

All decisions below are already accepted; none is pending.

1. Assumption: **H05** — Period grouping and per-section status ordering; Calendar unchanged. — Impact: HIGH
   Assumption answer: Approved explicitly with the corresponding specification or plan.

2. Assumption: **H07** — Existing destinations; focus and new collaboration/profile/notification features excluded. — Impact: HIGH
   Assumption answer: Approved explicitly with the corresponding specification or plan.

3. Assumption: **H02** — Exclusive session-retained scope, companion fallback to All. — Impact: HIGH
   Assumption answer: Approved explicitly with the corresponding specification or plan.

4. Assumption: **H03** — Filtered real counts and rounded completion percentage. — Impact: MEDIUM
   Assumption answer: Approved explicitly with the corresponding specification or plan.

5. Assumption: **H04** — Next uses pending starts at/after local minute, updated on clock/state changes. — Impact: MEDIUM
   Assumption answer: Approved explicitly with the corresponding specification or plan.

6. Assumption: **H01** — Neutral time-based greeting and existing avatar. — Impact: MEDIUM
   Assumption answer: Approved explicitly with the corresponding specification or plan.

7. Assumption: **H06** — Optional two-line Home notes; full notes through Edit. — Impact: MEDIUM
   Assumption answer: Approved explicitly with the corresponding specification or plan.

8. Assumption: **P03** — Retained Today provider and lifecycle-aware minute timer without minute database reads. — Impact: HIGH
   Assumption answer: Approved explicitly with the corresponding specification or plan.

9. Assumption: **P01** — Pure domain overview, existing loaders/schema/dependencies. — Impact: MEDIUM
   Assumption answer: Approved explicitly with the corresponding specification or plan.

10. Assumption: **P02** — Typed projection and shared stable comparator, deterministic companion order. — Impact: MEDIUM
   Assumption answer: Approved explicitly with the corresponding specification or plan.

11. Assumption: **P04** — Existing dashboard location, Home localization/widgets, opt-in card notes. — Impact: MEDIUM
   Assumption answer: Approved explicitly with the corresponding specification or plan.

## Fresh acceptance evidence

Final run: `.scratches/home-validation/20261117-235739/`, produced by
`bash .scratches/recheck-home.sh` from the repository root. All five stages in
`results.txt` pass: formatting, analysis, full tests, screenshot scenarios and
Android debug APK build. The full suite passes **383 tests**. Analysis reports
no errors/warnings; **48 SDK Material API deprecation infos** remain visible via
`--no-fatal-infos`, as allowed by the approved plan. The build retains the
existing future Kotlin-plugin migration warning and succeeds.

Eight screenshot scenarios generate **80 images** across en-US/pt-BR and
390×844 compact, 585×1920 reference-sized, 1200×900 wide and 320×800 doubled-text
layouts. They cover populated, complete, empty, empty filtered, companion,
loading, unavailable, editor, Undo and scrolled agenda states. Comparison uses
both Stitch Today HTML and image, with the approved shared card/navigation
interpretation. Normal text uses the horizontal chip strip; enlarged text
wraps. Header, counts, ring, notes, period sections, selected scopes and action
states were inspected. No missed-tap warnings or render exceptions remain.
The last run differs from the prior reviewed set only in the two enlarged Undo
images; both were re-reviewed with readable full-width messages and actions.

Native Android was launched with `--print-dtd` on emulator-5554. Fresh startup
covers state-lifetime changes; subsequent UI changes were hot reloaded
successfully. `native-home.png` in the final run verifies actual platform
rendering. `native-keyboard.png` verifies the blank editor's persistent actions
above the real keyboard; it was captured during this validation session before
the final shared Undo layout adjustment. The empty draft was dismissed without
saving. After real local midnight, `native-rollover.png` confirms November 18
and the morning greeting without restarting the app; live VM inspection also
confirmed the current loaded day, active timer and current header clock. No
device database was reset or populated with examples, and the user's
`app/pubspec.lock` matches the initial backup byte for byte. Fixture databases
are isolated under `.scratches/`.

### Red/Green and regression record

Initial tests preceded the new overview, state contracts, Home localization and
notes-preview implementation; missing APIs were the expected Red failures.
Focused Green runs then passed before composing the UI. The existing suite
first passed 380 tests. Subsequent behavioral/visual Red checks reproduced:

- Wrapped normal-size chips instead of the reference strip; keyboard scrolling
  and activation now reveal the last companion.
- Portuguese singular completion text; singular and plural counts now pass.
- Shared Undo foreground contrast of approximately 1.16:1; active action
  contrast now exceeds 4.5:1 against its inverse surface.
- Retained companion chips outside the viewport on remount; selection now
  scrolls into view without moving the page header.
- Keyboard focus loss while changing the selected chip; stable chip keys now
  preserve focus independently of the selection-reveal target.
- Narrow, broken-up enlarged Undo messages; a stacked layout gives the message
  full width and keeps recovery controls below it.

Logs are `.scratches/home-validation/{domain,state,presentation,home-ui}-red.log`,
`filter-strip-{red,green}.log`, `plural-red.log`,
`visual-recovery-{red,green}.log`, `filter-focus-{red,green}.log`, and
`undo-layout-{red,green}.log`. Task 5 tests existing mutation contracts through
the new overview; no additional mutation implementation was needed. Its initial
fixture included seeded examples and was corrected only inside the isolated
fixture database before the passing file-backed journey.

### Acceptance mapping

| Criteria | Current passing evidence |
| --- | --- |
| AC-HOM-001 | `home_localizations_test.dart`, `home_view_test.dart`: neutral greetings, boundaries and both locales; native header. |
| AC-HOM-002 | `home_overview_test.dart`: effective dates, deleted/completed eligibility and occurrence identities. |
| AC-HOM-003 | Overview and Home widget tests: exclusive scope, real companion identities, deduplication, fallback, keyboard reachability and visible restored selection. |
| AC-HOM-004–005 | Overview/localization/widget tests: 4/7 → 57%, pending/collaborative counts, zero and 100%; fresh state captures. |
| AC-HOM-006 | Overview and `today_home_state_test.dart`: eligible Next, time ties, minute ticks and same-day resume without storage reads. |
| AC-HOM-007 | Overview tests: 11:59/noon boundary, daily preference/explicit-window precedence, any-time group and stable per-section ordering. |
| AC-HOM-008–009 | `home_workflow_test.dart`, `task_workflow_integration_test.dart`: persisted create/edit, moving across noon, completion/reopen, stale write rejection, delete/Undo, postpone and storage reopen. |
| AC-HOM-010 | Cross-screen workflow: same shared Undo instance/window, committed recovery, retained Home filter through Calendar navigation. |
| AC-HOM-011 | Home state and existing `task_screen_state_test.dart`: day rollover, late range/streak replies, superseded results, paused/disposed timers and independent Calendar selection/filters. |
| AC-HOM-012 | State/widget/workflow tests plus existing task atomic-write/editor-save regressions: unavailable/retry, cleared stale metrics, safe failed writes and no action replay. |
| AC-HOM-013 | Overview/widget tests: zero matching scope, real zero summary and reset to All without writes. |
| AC-HOM-014 | Both-locale 320px/doubled-text labeled/48px guidelines, keyboard chip navigation/focus, optional two-line notes, Undo contrast/layout, full existing accessibility suite, 80 reviewed captures and native keyboard check. |

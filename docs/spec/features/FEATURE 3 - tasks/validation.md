# Task feature validation

Implementation: `feature/10-tasks-implementation` in the linked
`feature-10-tasks-implementation` worktree. The approved behavior and reviewed
assumptions remain unchanged.

Current acceptance evidence is the **2026-11-17 23:11:59 -03** recheck:
formatting, static analysis with informational notices nonfatal, all **358 tests**,
all **8 screenshot scenarios / 46 images**, and the Android debug APK build pass.
The images were reviewed against Stitch HTML and images; native Android create
and keyboard-visible screenshots supplement the fixture. See the final recheck
section below. Earlier results and sandbox blockers are historical only.

## Acceptance evidence

Paths in this table are relative to `app/test/`. Tests use real SQLite for
durability, constraints and transactions, and injected fakes for UI state.

| Acceptance criterion | Passing evidence |
| --- | --- |
| AC-TSK-001 | `calendar_task_actions_test.dart`, `task_editor_view_model_test.dart`, `task_workflow_integration_test.dart`: selected-date defaults, empty draft, disabled submission. |
| AC-TSK-002 | `tasks/task_database_write_test.dart`, `tasks/save_task_test.dart`, `task_workflow_integration_test.dart`: complete capture and file-backed reopen. |
| AC-TSK-003 | `task_editor_view_model_test.dart`, `task_editor_schedule_test.dart`: saved aggregate prefill and independent occurrence settings. |
| AC-TSK-004–005 | `task_editor_sheet_test.dart`: dirty Back/backdrop/drag, Keep editing and discard. |
| AC-TSK-006 | `task_value_objects_test.dart`, `task_schedule_values_test.dart`, `task_editor_subtasks_test.dart`, `task_editor_view_model_test.dart`: invalid fields retain draft and prevent writes. |
| AC-TSK-007 | `tasks/task_database_write_test.dart`, `task_editor_schedule_test.dart`: window/reminder clearing. No notification platform code is introduced. |
| AC-TSK-008–009 | `task_conflict_advisory_test.dart`, `task_editor_view_model_test.dart`: actual overlap, adjacency, self-exclusion, recurring competitors and advisory failures. |
| AC-TSK-010 | `task_editor_sheet_test.dart`, `task_editor_view_model_test.dart`: pending save locks, dismissal guards and progress. |
| AC-TSK-011 | `tasks/task_database_write_test.dart`, `tasks/task_atomic_schedule_save_test.dart`, `task_editor_view_model_test.dart`: injected child-write failure, rollback, stable draft retry. |
| AC-TSK-012–013 | `tasks/task_materialization_test.dart`, `tasks/task_recurrence_test.dart`: bounded/idempotent daily and weekly generation. |
| AC-TSK-014–015 | `tasks/task_streak_test.dart`, `task_completion_actions_test.dart`, `task_delete_undo_test.dart`: pending today, gaps, restore/reopen and original-date backfill. |
| AC-TSK-016–018 | `tasks/task_database_write_test.dart`, `tasks/task_materialization_test.dart`, `task_card_test.dart`, `task_editor_subtasks_test.dart`: stable checklist identities, active totals, independent parent state and new occurrence defaults. |
| AC-TSK-019 | `tasks/task_schedule_history_test.dart`, `tasks/task_atomic_schedule_save_test.dart`: tomorrow boundary, historical reconstruction, protected exceptions and atomic reconciliation. |
| AC-TSK-020 | `task_schedule_values_test.dart`, `tasks/task_materialization_test.dart`: calendar-date arithmetic across leap/month/year boundaries. |
| AC-TSK-021–023 | `task_completion_actions_test.dart`, `task_swipe_test.dart`, `task_card_test.dart`, `task_workflow_integration_test.dart`: explicit actions, exact threshold, cancellation and committed cross-screen refresh. |
| AC-TSK-024 | `postpone_task_test.dart`: local tomorrow, coexistence, original identity and affected dates. |
| AC-TSK-025–028 | `task_delete_undo_test.dart`, `task_actions_view_model_test.dart`, `task_undo_banner_test.dart`, `task_swipe_test.dart`: tombstones, conditional restore, stale tokens and elapsed recovery time. |
| AC-TSK-029 | `calendar_view_model_test.dart`, `task_screen_state_test.dart`, `task_workflow_integration_test.dart`: fresh loaders, stale-response protection and retained navigation/filter state. |
| AC-TSK-030–031 | `task_migration_test.dart`, `task_schema_test.dart`, existing startup/migration tests: preserved values/links, fresh and legacy versions, injected migration-stage rollback and stable history. Android upgrade also preserves the existing examples. |
| AC-TSK-032 | `today_tasks_view_test.dart`, `task_screen_state_test.dart`, `database_startup_test.dart`: empty/unavailable distinctions and actual counts. |
| AC-TSK-033–034 | `task_accessibility_test.dart`, editor/card/swipe widget tests, `task_localizations_test.dart`, `task_actions_view_model_test.dart`: Escape dismissal and launcher focus, modal Tab traversal, compact/doubled-text 48-pixel controls, keyboard-safe footer, explicit alternatives and accessible recovery timing. Rendered compact/wide/large-text checks supplement automation. |
| AC-TSK-035 | Rendered comparisons described below, including all card variants and four editor states. |

## Rendered comparison

Local screenshots are in `.scratches/task-design/` in the implementation
worktree. The temporary capture fixture is
`.scratches/task_design_capture_test.dart`; it uses in-memory data and does not
change the device database. English and Portuguese captures include daily,
weekly, one-time and completed cards; create, edit, validation and saving
editors; 390 × 844 compact and 800 × 900 wide layouts; enlarged text; and the
scrolled schedule, reminder and checklist sections. The wide editor is capped
at 560 logical pixels. Widget tests separately check the keyboard-safe footer.

Both Stitch HTML exports and images informed the comparison. The implementation
uses the approved project theme and identity, a serif title, rounded-square
completion control, grouped metadata and badge tray, and restrained priority
colors. Swipe reveals have localized Done/Delete labels and icons, with no
colored edges at rest. Cadence chips have dark readable labels on pale fills.
The modal retains section order, fixed actions, conditional controls and scope
guidance. Showcase framing and sample data are excluded.

Native Android screenshots `.scratches/tasks-native-today.png` and
`.scratches/tasks-native-create.png` verify the upgraded application and actual
platform fonts. The existing database was backed up locally before upgrade;
it was not reset. The fixture substitutes locally installed serif/sans fonts
for deterministic widget images; native screenshots verify platform rendering.

## Tooling and operational limits

Dart MCP was unavailable. Validation used the authorized Flutter/Dart CLI and
an Android emulator launched with `--print-dtd`. No new dependency, notification
delivery, web persistence, synchronization or remote service is introduced.
Reminder preferences are stored and explicitly labeled inactive. README
documents canonical schema version 4, legacy repeat opt-in and backup-based
rollback. Changes remain uncommitted in the implementation worktree.

## Subsequent Today and Calendar control refinements

The user requested floating Create task actions on Today and Calendar, Calendar
header creation replacing Today, Calendar-colored Today filters, and the Stitch
Calendar pill selector. These changes preserve the date defaults and action
guards. Undo sits above the floating action, and list padding reserves space.
The selector retains 48-pixel targets, keyboard-operable Material buttons,
localized labels and explicit selected semantics. Its visible height is larger
than the export to satisfy the project's minimum touch-target requirement.

Formatting and static analysis pass. Focused regression checks and the full
suite were attempted, but Flutter could not bind its local test socket in this
sandbox (`Operation not permitted`, errno 1); no assertions ran. Logs are
`.scratches/control-red.log` and `.scratches/control-full-tests.log`.
Rendered comparison and compact/enlarged-text verification remain pending.
There was no running app or Dart MCP available for hot reload. Existing visual
and test evidence above predates these control changes.

### Built-in segmented control follow-up

Replaced the custom pair of TextButtons with `SegmentedButton<bool>`, using
`ButtonSegment` labels for the reference's inset rounded white selection and
subtle shadow. Native single selection, semantics, Material feedback and touch
targets remain active; the selected icon and dividing line are hidden.
Formatting and static analysis pass. The updated widget regression requires
the native component and checks both selection states. Focused and full test
attempts cannot start because this sandbox forbids the local test socket;
rendered checks remain pending. Logs: `.scratches/segmented-red.log`,
`.scratches/segmented-tests.log`, and `.scratches/segmented-analyze.log`.

The requested commit before this change failed because Git metadata is mounted
read-only (`index.lock` could not be created). No commit or push occurred.

### Toggle capsule sizing correction

Reduced selected-label padding to 10 pixels horizontally and 2 vertically.
The neutral capsule now follows the scaled label line height plus 8 pixels,
independently of the native segmented button's padded touch targets. This
supersedes the earlier larger visible capsule: at the normal theme text size,
the visual capsule is 24 pixels tall while the interactive control retains
48-pixel targets. Increased text scales the capsule with its labels.

Formatting, static analysis and diff whitespace checks pass. Added a sizing
regression alongside the native selection checks. Focused and full tests were
attempted but could not open the local test socket, so no assertions or rendered
comparisons ran. Logs are `.scratches/toggle-sizing-{red,tests,analyze}.log`.

### Slight toggle size increase

Following visual feedback, increased labels to the existing `labelLarge` theme
style and selected-pill padding to 12 horizontal / 4 vertical pixels. The neutral
capsule follows the scaled line height plus 12 pixels: with the app theme it is
32 pixels tall and the selected pill is 28 pixels tall. Native padded touch
targets remain active. This supersedes Task 30's 24-pixel capsule.

Formatting and static analysis pass; sizing regression updated. Full tests were
attempted, with runtime/rendered verification still subject to the sandbox's
local socket restriction. Logs: `.scratches/toggle-enlarged-{tests,analyze}.log`.

### Sliding Calendar mode selection

A single decorative pill now moves beneath the native `SegmentedButton` using
`AnimatedAlign`, a 200 ms ease-in-out cubic transition, and directional alignment.
It retains the latest typography/capsule sizing and follows native selection
without custom input or focus handling. Reduced motion disables the transition.
Tests cover movement in both directions and immediate reduced-motion selection.

Formatting, analysis and diff checks pass. Focused and full test attempts remain
blocked at loading by the sandbox's local socket restriction; animation/runtime
and rendered verification are pending. Logs:
`.scratches/toggle-slide-{red,tests,analyze}.log`.

### Mode-chip click highlight correction

Disabled the native segmented button's splash and pressed/hover/focus overlay
paint, which used the larger hit region rather than the visible capsule.
Selection still slides normally. Focus is indicated with a label underline,
keeping a visible keyboard cue within the chip while preserving touch targets.

Formatting and static analysis pass. Updated the style regression and attempted
focused/full tests; execution and rendered verification remain blocked by the
sandbox's local socket restriction. Logs:
`.scratches/toggle-focus-{red,tests,analyze}.log`.

## 2026-11-17 recheck before starting Home

Rechecked at commit `21fd306` (Android toolchain upgrade). Compared the local
Stitch modal HTML/image, existing create/editor/native captures, and current
production code. The screenshots predate this recheck; they are comparison
evidence, not fresh captures or proof that the current Flutter SDK passes.

The comparison found missing editor-header context/separation, floating labels
in the empty form, an overly dark drag handle and default peach/checkmark
priority styling. Local fixes add the existing localized Personal task eyebrow,
forest heading and subtle header separator, light handle, always-visible field
labels, and a neutral native priority selector with colored dots and white
selection. There is no invented task/tag data or change to task persistence.

`app/test/task_editor_design_test.dart` adds four scenarios (en-US/pt-BR ×
390-pixel compact/320-pixel doubled-text layouts) for the header, field labels,
initial disabled submission, priority presentation and selection/date retention.
The visual fixture and existing behavioral tests still cover create/edit,
validation, saving, discard, scheduling, recurrence, reminders, subtasks,
completion, Undo and persisted cross-screen refresh. Coverage in source does
not establish a passing result for this recheck.

| Check | Current result |
| --- | --- |
| `dart format .` | Pass, no outstanding formatting changes. |
| Direct `dart analyze` | No errors/warnings; Flutter SDK Material API deprecation infos remain. |
| Focused existing editor/workflow tests | Blocked before loading tests: SDK cache `libimobiledevice.stamp` is read-only. |
| New design regression Red/Green | Both execution attempts blocked by the same SDK restriction; assertions not run. |
| Full `flutter test --no-pub` | Blocked by the same SDK restriction. |
| Fresh screenshot fixture | Blocked by the same SDK restriction. Existing captures not overwritten. |
| Native Android recheck | ADB cannot bind its local daemon socket (`Operation not permitted`). |
| GitHub project 15 via `gh` | `gh project view` fails; direct GraphQL cannot connect to `api.github.com`. |
| Refresh project access token | `gh auth refresh --hostname github.com --scopes project` cannot connect to GitHub; no refresh completed. |

Logs: `.scratches/task-recheck-{tests,full-tests,capture,format,dart-analyze}.log`
and `.scratches/task-design-recheck-red.log`.

**Gate remains open.** Do not mark Tasks complete or advance the project board
based on the older 350-test result. No issue/project state was changed and no
Home behavior was implemented. Home must be read from the actual issue after
Tasks passes, as requested. A session with writable Flutter caches and local
socket/network access is needed for the remaining checks and `gh` operations.

### Project board confirmed by the user's authenticated `gh` output

Project 15 contains Tasks issue #10 in **In Progress** and Home screen issue #7
in **Todo**. The Home issue body is empty. This replaces the earlier uncertainty
about issue identity/status; it does not establish that Tasks has passed or
supply additional Home acceptance criteria. No remote state has been changed.

A local recheck command is prepared for the user's normal terminal:
`bash .scratches/recheck-tasks.sh` from the repository root. It runs formatting
verification, Flutter analysis, the entire test suite, fresh visual fixtures,
and an Android debug APK build, preserving separate logs and per-check results
under `.scratches/task-recheck/<timestamp>/`. The latest run path is written to
`.scratches/task-recheck/latest-run.txt`. Checks continue after a failure so the
report captures every blocker; any failed command produces a nonzero exit.

The visual fixture now preserves the production button/chip typography instead
of overriding those styles. Only the deterministic local font substitution
remains. Its output directory is configurable with `TASK_CAPTURE_DIR`, so fresh
captures are kept apart from the historical screenshots. Generated screenshots
still require comparison with the reference before issue #10 can be closed.

## Final fresh recheck — 2026-11-17

`bash .scratches/recheck-tasks.sh` completed successfully. Evidence directory:
`.scratches/task-recheck/20261117-231159/`; each stage has its own log and
`results.txt` records five PASS results. The complete suite passed **358 tests**.
Eight capture scenarios generated **46 fresh images** with no missed-tap
warnings or rendering exceptions. All images were reviewed, including Create,
Edit, validation, saving, scrolled scheduling/checklist, card variants, Today,
and Calendar Month/Week in both locales, compact/wide and enlarged-text layouts.

The first actual runtime recheck reproduced 13 failures. Corrections add
localized icon-FAB tooltips, update obsolete text-button/filter expectations,
allow subpixel text-metric rounding, and keep oversized editor headings inside
the scroll body above fixed actions. Fresh visual review then reproduced tag
contrast, crowded shared headings, and off-screen enlarged Calendar controls
with six failing regressions (`.scratches/task-recheck/visual-red-confirmed.log`).
Selected tags now use white text on forest green, compact enlarged headings
use the full width, and Calendar creation/mode controls wrap. A further four-case
Red check (`priority-pill-red.log`) verifies independently rounded white priority
selection surfaces. The final full suite verifies all these fixes together.

Native Android was launched with `--print-dtd`; the final UI edit was hot
reloaded successfully (7 libraries). `native-create.png` and
`native-keyboard.png` in the evidence directory verify actual platform fonts,
empty labels/disabled submission, rounded priority selection and actions above
the keyboard. Opening the empty form did not save anything. No database reset
or dependency update was performed; the user's preexisting `pubspec.lock` is
byte-for-byte preserved against a local backup.

The approved design interpretation retains project typography, platform-native
controls and accessible hit targets rather than showcase framing/sample data.
At 320px and doubled text, headings/controls wrap or scroll and date grids retain
the calendar's existing horizontal scrolling. The fixed footer stays reachable.
Fixture fonts are locally substituted while preserving production typography;
explicit button/chip font-family substitution removes test-font placeholder
blocks without changing production styles.

Analysis runs `flutter analyze --no-pub --no-fatal-infos`: **no errors or
warnings**, with 38 informational notices for the SDK's deprecation of
`flutter/material.dart` and its Material localization shim. These notices remain
visible in `analysis.log`; a full migration to the separate Material package is
outside this UI correction. The APK builds successfully and retains the SDK's
future Kotlin-plugin migration warning. Neither notice is a current build or
behavior failure. Historical sandbox/network restrictions no longer apply;
authenticated `gh` access to issues and project 15 was verified.

## GitHub completion

Corrections were committed and pushed as `0627006` on
`feature/10-tasks-implementation` after checking local time (outside
09:00–18:00). Issue #10 is closed as completed and its project 15 card is Done.
Home issue #7 was then moved to In Progress; its initial specification is a
review draft under `FEATURE 4 - home screen`, with no implementation plan,
task checklist or production Home behavior added before approval.

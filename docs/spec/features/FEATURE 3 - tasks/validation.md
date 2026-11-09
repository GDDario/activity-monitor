# Task feature validation

Implementation: `feature/10-tasks-implementation`, in the isolated worktree
`.scratches/tasks-implementation`. The approved behavior and assumptions remain
unchanged. Sol High handled persistence, recurrence, coordination and integration;
Terra High handled bounded values and presentation.

Final gates: `dart format .` completed, `flutter analyze --no-pub` reported no
issues, and `flutter test --no-pub --reporter compact` passed all **350 tests**.
The temporary visual fixture also passed both locale capture cases.

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

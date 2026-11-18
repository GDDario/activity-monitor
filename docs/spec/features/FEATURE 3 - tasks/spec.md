# SECTION 1: SPEC

## One-line purpose

Let users create, edit, schedule, complete, postpone, and recover personal tasks
through accessible task cards and a calm, consistent task editor.

## Status and reviewed scope

Implemented and validated in `feature/10-tasks-implementation`; see
[validation.md](validation.md) for acceptance evidence and visual checks.
The user explicitly accepted all 24 spec assumptions;
their inline markers have been removed without changing the agreed behavior.
The individual decisions remain recorded as S01–S24 in [plan.md](plan.md).

The user requested task cards and create/edit modals following the Stitch
`task_cards_swipe_gestures` and `create_edit_task_modal` designs, including the
database tables and architectural structure. The user subsequently confirmed:
**deliver daily/weekly recurrence, streaks, and subtasks; store reminder settings
for later notification delivery.** These scope decisions are not assumptions.

The behavioral specification is followed by a technical appendix containing the
explicitly requested data and architecture proposal. This appendix forms part of
the approved specification; it does not replace the separately reviewed
implementation plan or implementation checklist.

## Sources and feature boundaries

- Governance: [constitution](../../project/constitution.md),
  [architecture](../../project/architecture.md),
  [conventions](../../project/conventions.md), and
  [design reference](../../project/design-reference.md).
- Persistence: [ADR 0001](../../../adr/0001-use-sqlite.md).
- Existing behavior: [application foundation](../FEATURE%201%20-%20application%20foundation/spec.md)
  and [calendar](../FEATURE%202%20-%20calendar/spec.md).
- Card reference: [Stitch HTML](../../../../.scratches/stitch_shared_activity_tracker/task_cards_swipe_gestures/code.html)
  and [image](../../../../.scratches/stitch_shared_activity_tracker/task_cards_swipe_gestures/screen.png).
- Modal reference: [Stitch HTML](../../../../.scratches/stitch_shared_activity_tracker/create_edit_task_modal/code.html)
  and [image](../../../../.scratches/stitch_shared_activity_tracker/create_edit_task_modal/screen.png).

The local Stitch exports include controls below the image's visible scroll
area; both the HTML and image MUST inform implementation. They are design
references, not working persistence or domain implementations. The showcase's
tabs, simulator frame, explanatory state cards, and sample content are not
application screens. The `.scratches/` exports are local working artifacts;
the normative design interpretation below remains part of this specification.

This feature extends the calendar's read-only agenda with mutations and replaces
the foundation's presentation-only Today task examples with persisted tasks.
The calendar retains ownership of navigation, date selection, filters, grid,
and filtered counts. Its original exclusions of task actions and recurrence
expansion apply to FEATURE 2; this feature introduces those capabilities.

Creation MUST be available as a floating action button on Today and Calendar.
Calendar MUST also replace its Today header action with Create task. Its
Month/Week selector MUST use Flutter’s built-in `SegmentedButton` and follow
the rounded pill treatment in the Stitch
calendar reference, while retaining accessible touch targets and selected
states. Its selected pill SHOULD slide smoothly between Month and Week,
and MUST move immediately when the system requests reduced animation.
Today filters MUST use the same selected and unselected colors as the
Calendar cadence filters. These controls are explicit user-requested UI
refinements. Calendar creation
defaults to its selected date, and Today creation defaults to the current local
date. Today lists occurrences due today and derives its task counts/progress
from those occurrences. Existing dashboard section labels may adapt to actual
data; unrelated navigation and focus-session features remain unchanged.

Task creation is personal and local to one device. Existing
participant associations remain visible and survive edits, but this editor has
no participant assignment, invitations, synchronization, or authentication. Task
details, focus timers, a separate archive, arbitrary custom recurrence, and
notification delivery are outside this feature. Custom cadence is visibly
unavailable rather than selectable without functioning behavior.

## Users and use cases

- As a user, I want to capture a named task with optional context so that I can
  plan an activity without filling unnecessary fields.
- As a user, I want to edit a saved task with its existing values prefilled so
  that I can revise my plans without losing information.
- As a user, I want daily habits and weekly tasks to appear on their scheduled
  dates so that I do not recreate them manually.
- As a user, I want to see streaks and subtask progress so that I can understand
  my progress from recorded activity.
- As a user, I want fast card actions and accessible alternatives so that I can
  manage tasks using touch, a keyboard, or assistive technology.
- As a user, I want to undo an accidental completion or deletion so that small
  interaction mistakes do not cost my task data.
- As a user, I want changes to survive restarting the app so that my schedule
  remains dependable offline.

## Requirements

1. **REQ-TSK-001 — Shared cards:** Today and the selected-day calendar agenda
   MUST use the same task-card behavior and state meanings. Cards MUST show the
   title, completion control, cadence, and actions menu. Available date/time,
   selected tags, priority, participant names, subtask progress, reminder
   preference, and enabled daily streak MUST reflect saved data. Missing
   optional metadata MUST NOT be replaced with invented values.
2. **REQ-TSK-002 — Card variants:** Pending daily, pending weekly, pending
   one-time, and completed cards MUST follow the corresponding Stitch variants.
   A completed card MUST have a checked control, subdued readable styling,
   struck-through title, completion feedback, and an accessible way to reopen
   it. A known completion time MUST be displayed in the current locale; an
   unknown historical time MUST show a generic completed label.
3. **REQ-TSK-003 — Direct actions:** A pending card's menu MUST provide Mark
   Done, Edit Task, Postpone to Tomorrow, and Delete. A completed card MUST
   provide Reopen, Edit Task, and Delete; postponement MUST be unavailable.
   Menus MUST dismiss predictably and return focus to their trigger.
4. **REQ-TSK-004 — Create editor:** Creation MUST open an empty, labeled form
   with Create Task, Cancel, and close controls. Submission MUST remain disabled
   until the required title and schedule are valid. Defaults are
   low priority, one-time cadence, no tags or subtasks, no time window, no
   reminder, and streak tracking off.
5. **REQ-TSK-005 — Edit editor:** Edit MUST load the saved task and selected
   occurrence, including notes, tags, priority, scheduling preferences, and
   subtask state, and offer Save changes and Discard. Opening or discarding an
   editor MUST NOT persist changes. Missing or deleted records MUST show a
   presentation-safe unavailable message instead of opening a new task.
6. **REQ-TSK-006 — Task details:** The editor MUST require a non-whitespace
   title and support optional multiline notes, selecting and adding context
   tags, and exactly one priority: low, medium, or high. Titles
   are trimmed and limited to 200 characters; notes to 10,000 characters;
   tags to 32 characters and ten selected tags per task. Tag identity uses
   trimmed, case-insensitive names without a leading display `#`; original
   display casing is preserved.
7. **REQ-TSK-007 — Scheduling:** Every task occurrence MUST have a valid local
   scheduled date. The editor MUST offer an optional specific time window;
   enabling it MUST reveal editable start/end times and duration. A window
   MUST end after it starts. Disabling it MUST save no time window or reminder.
   Windows are within one local calendar day; overnight windows
   are rejected with field guidance. Past dates are permitted.
8. **REQ-TSK-008 — Reminder preferences:** Timed tasks MUST support saving and
   reopening a reminder preference. No permission request, scheduled alert,
   sound, or delivery guarantee MUST be introduced. Reminder information on
   cards and in the editor MUST explicitly communicate that it is a saved
   preference and notifications are not yet active. Options are
   Off, At start, 5, 15, 30, or 60 minutes before, defaulting to Off; the
   reference's Calm Chime is a future delivery treatment, not a sound selector.
9. **REQ-TSK-009 — Cadence:** The editor MUST support one-time, daily, and
   weekly cadence. Weekly MUST reveal weekday selection and require at least
   one day. Daily MUST reveal streak tracking and an optional morning,
   afternoon, or evening preference. Daily means every calendar
   day; weekly means every week on the selected weekdays; new weekly tasks
   initially select the scheduled date's weekday. Day-period preferences are
   labels and do not infer a time window. The chosen start date is a lower
   bound: a weekly task's first occurrence is its first selected weekday on
   or after that date. New daily/weekly tasks enable recurrence on save.
10. **REQ-TSK-010 — Recurring occurrences:** Daily and weekly schedules MUST
    produce independent dated occurrences from their start date, including
    matching future calendar dates on navigation, without duplicate
    occurrences when reloading or restarting. Merely navigating MUST NOT mark
    missed occurrences complete. Deleting or moving an occurrence MUST NOT
    cause its original scheduled slot to be regenerated.
11. **REQ-TSK-011 — Edit scope:** The editor MUST make the effect of an edit on
    a recurring task clear before saving. Title, notes, tags,
    priority, reminder/time defaults, and subtask definitions belong to the
    recurring task and are shared across its cards, including historical
    cards. Recurrence changes take effect from tomorrow, preserving past and
    today's occurrences, completed occurrences, and explicitly moved/deleted
    occurrences. The selected occurrence's date/time can be edited as an
    exception without moving the series. A one-time task's date/time edit
    moves its only occurrence.
12. **REQ-TSK-012 — Subtasks:** The editor MUST support adding, renaming,
    completing, reopening, deleting, and ordering subtasks. The card MUST show
    the number complete and total, with a progress indicator only when at
    least one active subtask exists. Subtask changes in the editor MUST remain
    draft changes until Save. Up to 50 subtasks, each with a
    trimmed nonblank title of at most 200 characters; new recurring occurrences
    start with all subtasks pending. Accessible move-up/down actions accompany
    drag ordering.
13. **REQ-TSK-013 — Completion:** A checkbox, Mark Done, or committed right
    swipe MUST complete only the selected occurrence. Reopen MUST return only
    that occurrence to pending and clear its completion time. Repeating the
    same completion intent MUST NOT toggle it back or create extra records.
    Parent and subtask completion are independent; completing all
    subtasks does not automatically complete the parent, and completing or
    reopening a parent does not change its subtasks.
14. **REQ-TSK-014 — Streaks:** Enabled daily streaks MUST be calculated from
    saved completions for that task and update after completion, reopen,
    deletion, or Undo. Disabling tracking MUST hide the streak without erasing
    completions. The streak MUST NOT be an editable or hardcoded count.
15. **REQ-TSK-015 — Postponement:** Postpone to Tomorrow MUST move only the
    selected pending occurrence to the next date after the current local date,
    preserving its identity, metadata, subtask state, and duration. Calendar
    indicators and counts MUST update for both dates. An
    occurrence already due tomorrow produces an informational no-op. A moved
    recurring occurrence may coexist with tomorrow's normal occurrence; they
    remain distinct and MUST NOT be merged.
16. **REQ-TSK-016 — Swipe mechanics:** A horizontal right swipe MUST reveal a
    forest-green Done action; a left swipe MUST reveal a terracotta Delete
    action. Releasing after reaching 90 logical pixels in the action direction
    MUST commit exactly once; releasing before it or cancelling MUST restore
    the resting card without a mutation. Vertical scrolling MUST remain
    available. Right swipe on a completed occurrence MUST be a no-op;
    reopening uses its explicit controls. Optional haptics MUST NOT be required
    to understand success.
17. **REQ-TSK-017 — Delete and Undo:** Deletion MUST immediately remove the
    occurrence from visible agendas and counts after persistence succeeds and
    offer Undo with the reference's five-second recovery window. Undo MUST
    restore the same identity, date/time, completion, tags, subtasks, and
    participant associations. Completion MUST also offer Undo. Deletion removes only one occurrence, never the series; completed is not
    a separate archived lifecycle. Completion Undo also lasts five seconds.
    Only the latest undoable action has an active banner; replacing it ends
    the previous window. Windows pause while the banner has keyboard or
    assistive-technology focus and respect accessible timeout extensions.
18. **REQ-TSK-018 — Editor states:** The editor MUST implement populated edit,
    empty create, validation/error, and saving states. Labels MUST stay
    visible when fields contain text. Invalid fields MUST expose inline
    guidance and focus the first invalid field after an attempted submission.
    Errors MUST NOT erase valid draft values.
19. **REQ-TSK-019 — Conflict advisory:** Overlapping timed pending occurrences
    on the same effective local date MUST produce a nonblocking scheduling
    advisory. The current occurrence MUST be excluded from its own conflict
    check. A valid task MUST remain saveable despite an overlap.
20. **REQ-TSK-020 — Saving and dismissal:** While saving, all editor mutation
    controls, repeat submission, and dismissal MUST be disabled and an
    accessible saving indicator MUST appear. Success MUST close the editor
    and update affected visible data. Failure MUST retain the draft, restore
    interaction, show a safe error, and allow retry. Before
    saving, close, backdrop, Back/Escape, and sheet dragging discard a clean
    draft immediately; dirty drafts require Keep editing or Discard changes.
21. **REQ-TSK-021 — Durable consistency:** Every create, edit, completion,
    postpone, delete, and Undo MUST survive restart as one all-or-nothing
    change. Failed writes MUST NOT leave partial task/subtask/tag changes or
    announce success. A successful write MUST refresh Today and Calendar
    without requiring app restart or losing calendar selection and filters.
22. **REQ-TSK-022 — Loading and concurrency:** Loading, empty, and unavailable
    states MUST remain distinct. Actions on an occurrence MUST be disabled
    while its mutation is pending. A stale edit or Undo MUST NOT overwrite a
    newer mutation; it MUST report the conflict and allow reloading.
23. **REQ-TSK-023 — Compatibility:** Existing calendar entries, identifiers,
    dates, completion flags, and participant links MUST be preserved on
    upgrade. Existing completed entries without a recorded completion time
    MUST NOT be assigned an invented time. Each legacy calendar
    entry becomes an independent task with one stored occurrence; its cadence
    label is preserved, but automatic recurrence stays disabled until the
    user explicitly enables it in the editor. Existing example entries remain
    identifiable as examples and MUST NOT expand automatically. A legacy
    non-repeating daily/weekly task shows explanatory guidance and an explicit
    Enable repeating schedule control; opening and saving unrelated details
    does not implicitly enable it.
24. **REQ-TSK-024 — Localization and accessibility:** All feature-owned labels,
    errors, dates, times, counts, and plural forms MUST support en-US and pt-BR.
    Cards, menus, and editors MUST support keyboard focus, screen readers,
    visible selected states, reduced motion, enlarged text, and controls with
    at least 48-by-48-logical-pixel hit targets. Every swipe action MUST have
    an equivalent explicit control. Save and Undo outcomes MUST be announced.
25. **REQ-TSK-025 — Responsive design:** Compact layouts MUST present a bottom
    sheet with handle, close control, scrollable form, and persistent action
    footer. Wide layouts MUST offer a bounded dialog with the same form and
    behavior. The keyboard, safe areas, and enlarged text MUST NOT obscure
    the focused field, error guidance, or actions.
26. **REQ-TSK-026 — Data safety:** Unavailable storage or failed migration MUST
    preserve existing records and display a safe unavailable state. The app
    MUST NOT silently recreate storage, replace user data with examples, or
    expose task titles/notes in diagnostic output.

## Business rules

- **Identity and ownership:** A `TaskId` identifies a task definition; an
  `OccurrenceId` identifies one scheduled occurrence of it. Completion,
  postponement, deletion, and Undo target `OccurrenceId`. A `TaskSchedule`
  defines one-time, daily, or weekly cadence independently of completion.
- **Domain invariants:** `TaskTitle`, `TagName`, `SubtaskTitle`, `LocalDate`,
  `LocalTimeWindow`, `WeeklyDays`, and `ReminderPreference` own their validity
  rules. The presentation displays validation outcomes; it does not maintain
  a second independent set of business rules. A weekly schedule has at least
  one weekday, and a reminder requires a time window.
- **Local calendar semantics:** Dates and wall times follow the device's local
  calendar. Local dates are not UTC instants. Completion timestamps are
  instants displayed in the current locale/time zone. Travelling
  leaves scheduled wall dates/times unchanged; no time-zone identifier or
  cross-device scheduling is introduced.
- **Recurrence identity:** At most one normal occurrence exists per task and
  original scheduled date. Its effective date can differ after postponement.
  Completion and deletion preserve the original slot identity. A recurrence
  starts no earlier than its start date and does not require an end date.
- **Recurrence edits:** Under the reviewed edit scope, applying a new
  rule replaces only untouched, pending future slots. Past, today's,
  completed, explicitly rescheduled, and deleted slots remain intact. A
  cadence change to one-time stops new repeats from its effective date while
  retaining those protected occurrences. The editor MUST disclose this effect.
- **Streak definition:** A streak is consecutive original scheduled
  local dates completed for one enabled daily task. If today's occurrence is
  pending, the run ends yesterday; if it is completed, it ends today. Missing,
  pending, or deleted earlier dates break the run; future dates are excluded.
  A postponed occurrence counts for its original date when eventually
  completed, allowing intentional backfill. No completion before the daily
  schedule's effective start contributes.
- **Checklist identity:** Subtask definitions have stable `SubtaskId`s; their
  completion belongs to an occurrence. Reordering or renaming retains that
  identity and its state. Deleting a definition removes it from
  all displayed checklists but retains historical state internally; unchanged
  definitions retain completion, and added definitions start pending.
- **Conflict intervals:** Two windows overlap when each starts before the
  other ends. Adjacent windows do not overlap. Untimed, completed, or deleted
  occurrences do not reserve a conflicting window. The advisory
  checks the selected occurrence's effective date, not every future repeat.
- **Visibility and ordering:** Deleted occurrences contribute to no visible
  task count, calendar indicator, subtask summary, or streak. Pending cards precede completed cards; within each group timed occurrences
  sort by start time, untimed occurrences last, then title and identity.
- **Recovery:** Undo is an inverse mutation conditional on the action still
  being current. It restores the previous occurrence state rather than
  creating another task. Expiry does not undo a successful action.
  Restarting closes outstanding Undo windows; committed deletion
  remains effective. Recovery of an entire recurring series is not needed
  because deleting a series is not exposed in this feature.

## Design interpretation

The project design reference governs shared tokens where Stitch exports differ
in font families, radii, sample branding, and color aliases. Reuse established
theme tokens and application identity. Preserve the following component intent:

| Design element | Required interpretation |
| --- | --- |
| Pending card | Warm light surface, soft corners, generous spacing, leading completion control, editorial title, trailing overflow menu, grouped metadata tray. |
| Cadence and priority | Sage habit/weekly pills, neutral one-time pill, restrained amber/terracotta priority emphasis, text/icons in addition to color. |
| Progress | Real subtask fraction and subtle progress bar; real enabled daily streak only. |
| Completed card | Readable subdued surface, checked state, struck-through title, known completion time, explicit Reopen/Undo Completion control. The sample Archived badge does not introduce archival behavior. |
| Swipe | Foreground follows horizontal drag; green Done canvas appears on the left and terracotta Delete canvas on the right; 90-logical-pixel release threshold. |
| Feedback | Calm inverse-surface success/recovery banner with accessible Undo and deletion countdown. |
| Editor shell | Dimmed backdrop, compact bottom sheet, visible heading/close, independently scrolling body, persistent Cancel/Discard and Create/Save footer. |
| Editor body | Task Details, Scheduling & Cadence, and Subtasks Checklist sections in the reference order, with conditional time/weekly/daily controls. |
| Form states | Empty create, prefilled edit, inline validation plus nonblocking conflict advisory, and locked saving state with progress indicator. |

Small visual icons in the exports MUST receive larger interaction hit regions.
Demo sample tasks, fixed dates, streak counts, fake conflict names, and technical
saving copy MUST NOT become product data or promises. Saving copy MUST simply
describe saving the user's task.

## Edge cases

| Situation | Expected behavior |
| --- | --- |
| Empty/whitespace title, blank subtask, invalid date, excessive field length, or no weekly days | Field-specific error; preserve the draft and persist nothing. |
| End time equals/precedes start, or reminder without a window | Reject the inconsistent schedule; toggling the window off clears the saved reminder. |
| Matching windows, including a recurring occurrence | Show an advisory and permit saving; ignore the same occurrence during edits. |
| Leap day, month/year boundary, or daylight-saving clock change | Recurrence and tomorrow use calendar-date arithmetic; daily dates are neither skipped nor duplicated by elapsed-hour calculations. |
| Recurring occurrence moved onto another normal occurrence | Keep both identities, show both, update counts, and show an overlap advisory if timed windows overlap. |
| Right swipe on completed card, partial swipe, cancelled gesture, or vertical scroll | Do not mutate; restore resting presentation where needed. |
| Write fails after draft child changes | Roll back the entire change, retain the draft, show an error, and allow retry. |
| Stale editor, removed record, or Undo after a subsequent edit | Do not overwrite new state; show a safe conflict/unavailable message. |
| Restart after deletion or navigation back to its original date | Keep it absent; recurrence must not regenerate that slot. |
| Legacy daily/weekly example with no recurrence definition | Show its saved cadence and occurrence only until recurrence is explicitly enabled. |
| Unsupported local storage target | Show unavailable; no transient in-memory success or notification promise. |
| No tasks, no subtasks, or no tags | Show helpful empty content; no fabricated examples, zero-denominator progress, or empty metadata separators. |

## Acceptance criteria

Each scenario is binary and applies in both supported locales where relevant.

### Capture and editing

```text
AC-TSK-001
Given Today or a selected Calendar date
When the user chooses Create Task
Then an empty editor opens with the appropriate default date and disabled Create task action until its required values are valid

AC-TSK-002
Given a valid named one-time task with optional notes, tags, priority, time window, reminder preference, and subtasks
When the user saves and restarts the app
Then exactly one task and occurrence exist with those values and the task appears on its scheduled date

AC-TSK-003
Given a saved task with checked subtasks
When Edit Task is opened
Then the saved values and the selected occurrence's subtask states are prefilled and Save changes is available for a valid form

AC-TSK-004
Given an edited draft with unsaved changes
When dismissal is attempted and Keep editing is chosen
Then the draft remains unchanged and no stored values change

AC-TSK-005
Given an edited draft with unsaved changes
When Discard changes is confirmed
Then the editor closes and stored values remain unchanged

AC-TSK-006
Given a whitespace title, blank subtask title, invalid time window, or weekly schedule without selected weekdays
When validation runs or submission is attempted
Then the relevant error is exposed and no partial change is saved

AC-TSK-007
Given a task with a time window and saved reminder preference
When the time window is disabled and saved
Then the window and reminder are cleared and no notification is scheduled

AC-TSK-008
Given an existing timed pending occurrence from 15:00 to 16:00
When another task is drafted for the same date from 15:30 to 16:30
Then an overlap advisory appears and valid submission remains enabled

AC-TSK-009
Given an existing occurrence from 15:00 to 16:00
When that occurrence is edited without changing its window, or a second window starts at 16:00
Then neither the occurrence itself nor the adjacent window produces an overlap advisory

AC-TSK-010
Given a valid draft
When Save begins
Then submission, all mutation controls, and dismissal remain disabled until the write finishes and progress is announced

AC-TSK-011
Given an editor save fails during a child-record write
When the failure is presented
Then no task changes are committed, the complete draft remains available, and a retry can save it once
```

### Recurrence, streaks, and checklist

```text
AC-TSK-012
Given an enabled daily task starting January 30
When Calendar displays January 30 through February 2 and that range is reloaded
Then one normal occurrence exists on each of those four dates and no duplicate is created

AC-TSK-013
Given an enabled weekly task starting Wednesday with Monday and Thursday selected
When its first two weeks are viewed
Then only matching weekdays on or after its start date have normal occurrences

AC-TSK-014
Given a daily task with yesterday and the preceding day completed, today pending, and the date before them missed
When streak tracking is enabled
Then its streak is two and becomes three when today's occurrence is completed

AC-TSK-015
Given a three-day daily streak ending today
When the middle occurrence is reopened or deleted
Then the streak becomes one and restoring that completion with a valid Undo restores three

AC-TSK-016
Given a task with three active subtasks and two completed on one occurrence
When its card is displayed and a later recurring occurrence is created
Then the first card shows 2/3 and the later occurrence starts at 0/3

AC-TSK-017
Given a pending parent with all subtasks completed
When it is saved
Then the parent remains pending until a parent completion action occurs

AC-TSK-018
Given an edited checklist with reordered, renamed, added, and removed subtasks
When Save succeeds
Then active definitions reflect the saved order, unchanged identities retain their occurrence state, and new definitions are pending

AC-TSK-019
Given a recurring task with historical completions, today's occurrence, untouched future slots, and moved/deleted exceptions
When its recurrence weekdays change
Then the new rule applies from tomorrow, untouched pending future slots are reconciled, and protected occurrences retain their identities and state

AC-TSK-020
Given an enabled daily task spanning a daylight-saving change or February 29
When the affected dates are viewed
Then each matching local date has one normal occurrence regardless of elapsed hours
```

### Card actions and recovery

```text
AC-TSK-021
Given a pending occurrence
When its checkbox, Mark Done, or a right swipe released at 90 logical pixels completes it
Then only that occurrence becomes done, its completion instant is recorded, and Today/Calendar counts refresh

AC-TSK-022
Given any card at rest
When a horizontal drag is released below 90 logical pixels or cancelled
Then the card returns to rest and no completion or deletion is persisted

AC-TSK-023
Given a completed occurrence
When Reopen is selected
Then it becomes pending, its completion time is cleared, and its subtasks remain unchanged

AC-TSK-024
Given a pending occurrence due today and a normal recurring occurrence already due tomorrow
When Postpone to Tomorrow is selected
Then the first occurrence moves to tomorrow with its identity and checklist intact, both occurrences remain distinct, and today's counts decrease

AC-TSK-025
Given an occurrence with saved tags, participant links, completion, and subtask states
When Delete is selected or a left swipe is released at 90 logical pixels
Then that occurrence disappears from agendas, counts, and indicators and a five-second Undo banner appears

AC-TSK-026
Given a deleted occurrence within its active Undo window
When Undo succeeds
Then the same occurrence and all its prior state return without creating another task

AC-TSK-027
Given a deleted recurring occurrence whose Undo window expired
When the app restarts and its original date is viewed
Then the deleted slot remains absent and other series occurrences remain available

AC-TSK-028
Given an occurrence changed after an earlier undoable completion
When that earlier Undo is attempted
Then it reports a conflict and preserves the newer state
```

### Integration, upgrade, and presentation

```text
AC-TSK-029
Given a calendar selection with cadence and participant filters
When a matching occurrence is edited, completed, moved, deleted, or restored
Then entries, indicators, and pending/done counts reflect committed data without resetting selection or filters

AC-TSK-030
Given a supported legacy database with pending/done entries and participant links
When the feature migration succeeds and the app restarts
Then existing entry identities, dates, titles, cadence labels, completion flags, and links remain available without enabling automatic repeats or inventing completion times

AC-TSK-031
Given a legacy database and a migration that fails partway through
When initialization returns an error
Then the original records, schema version, and migration history remain consistent and no success or empty-data state is shown

AC-TSK-032
Given task storage is empty or unavailable
When Today or Calendar loads
Then it shows the appropriate empty or unavailable state and no hardcoded task counts or examples

AC-TSK-033
Given en-US or pt-BR, compact or wide layout, enlarged text, and a keyboard or screen reader
When cards, menus, and every editor section are used
Then essential content and actions remain reachable, focus stays within the open editor, and focus returns to the launcher after dismissal

AC-TSK-034
Given gestures are unavailable or reduced motion is enabled
When the user completes, edits, postpones, deletes, or reopens an occurrence
Then explicit controls provide the same persisted outcomes and accessible feedback

AC-TSK-035
Given the task cards and all four editor states
When compared with the two Stitch exports at matching viewports
Then they satisfy the design interpretation, conditional field behavior, shared project tokens, and accessible interaction sizes
```

## Technical appendix — requested data and architectural structure

This appendix specifies the proposed technical scope for review. The later
`plan.md` will turn the approved choices into implementation contracts and
sequencing; `tasks.md` will be created after plan approval.

### Architectural responsibilities

Retain the project's layer-first organization and dependency rules. Construct
dependencies at the application composition boundary. Domain components MUST
remain independent of Flutter, SQLite, and presentation state.

The following feature-specific components implement the requested
behavior using existing Riverpod composition, the injected UUID generator,
database initialization, localization, and shared theme. No new package is
required by this proposal.

```text
app/lib/
  app/dependencies/             task providers, composition, shared refresh
  domain/models/               Task, TaskOccurrence, TaskSubtask, TaskSchedule
  domain/value_objects/        TaskId, OccurrenceId, TaskTitle, LocalDate,
                               LocalTimeWindow, WeeklyDays, ReminderPreference
  domain/use_cases/            SaveTask, EnsureTaskOccurrences,
                               CompleteTaskOccurrence, ReopenTaskOccurrence,
                               PostponeTaskOccurrence, DeleteTaskOccurrence,
                               UndoTaskOccurrenceAction, CalculateDailyStreak
  data/repositories/           TaskRepository contract and local implementation;
                               CalendarRepository read projection
  data/services/              TaskDatabase service; CalendarDatabase reads
  data/services/database/
    migrations/               new numbered task-schema migration
  ui/tasks/
    view_models/              TaskEditorViewModel, TaskActionsViewModel
    views/                    TaskEditorSheet / responsive dialog
    widgets/                  TaskCard, TaskActionsMenu, checklist, Undo banner
  ui/dashboard/               TodayViewModel and persisted task sections
  ui/calendar/                existing CalendarViewModel and agenda integration
```

The request flow is View → ViewModel → Use Case → Repository → Service. Use
cases own schedule expansion, recurrence reconciliation, streak calculation,
and coordinated mutations; they depend on repository contracts. Simple
single-source reads MAY go ViewModel → Repository with no read use case.

- Views render immutable state and forward intent; they MUST NOT access
  repositories or services. Drag animation and focus remain view concerns.
- Editor ViewModel owns its draft, field errors, dirty/saving state, and save
  command. Card-actions ViewModel owns in-flight actions and Undo presentation.
- TaskRepository is the single source of truth for task aggregates and
  occurrences, with atomic writes and observable/invalidation notifications
  emitted only after commit. It MUST NOT depend on CalendarRepository.
- CalendarRepository remains a read projection over the same canonical task
  tables; it MUST NOT keep an independently writable copy of tasks.
- A successful task write invalidates/reloads affected Today and Calendar
  projections. The current cached calendar future MUST be replaced/refreshed;
  rereading the same resolved future is insufficient. A failed write emits no
  success event. Calendar UI selection/filter state survives refresh.
- Services own parameterized SQL, transaction mechanics, connection lifecycle,
  and row mapping. ViewModels and use cases MUST NOT depend on services.
- Inject the clock and UUIDv7 generation. Keep database work off the UI isolate
  using the established initialization/read pattern and an equivalent write
  boundary; connections are opened with foreign keys enabled and closed by
  their owner. Mutation transactions are short and contain no UI waits.

### Domain and table proposal

Use `tasks` as recurring definitions and `task_occurrences` as
materialized dated instances. Normalize tags, weekdays, and checklist state as
below; reuse `calendar_participants` to preserve existing participant identity.
This replaces the legacy writable entry tables instead of maintaining two
competing task stores.

All new entity IDs use injected UUIDv7 stored as non-null TEXT primary keys;
existing IDs remain valid. Times marked UTC are persisted instants; local dates
are validated `YYYY-MM-DD` values and local times are minutes since midnight.
Integer booleans have `CHECK (... IN (0, 1))`. Nonnegative revisions support
conditional writes; each aggregate edit increments its revision. Enum fields
have explicit allowed-value constraints. Domain validation owns semantic date
and text rules; database checks provide additional structural guarantees.

| Table | Fields and constraints |
| --- | --- |
| `tasks` | `id`; nonblank `title`; nullable `notes`; `priority` (`low`, `medium`, `high`); `cadence` (`one-time`, `daily`, `weekly`); `recurrence_enabled`; `start_date`; nullable `rule_effective_date`; nullable paired `start_minute`, `end_minute` with `0 <= start < end < 1440`; nullable `reminder_minutes_before` in 0, 5, 15, 30, 60, requiring a window; `streak_enabled`, allowed only for enabled daily recurrence; nullable `day_period` (`morning`, `afternoon`, `evening`), allowed only for daily cadence; `revision`; nullable `created_at_utc`, `updated_at_utc` for legacy provenance. Newly created tasks supply both timestamps; editing a legacy task supplies its update time without inventing its creation time. One-time cadence requires recurrence disabled. |
| `task_weekdays` | `task_id` FK → tasks, `weekday` 1–7 (Monday–Sunday); composite primary key. Used only by enabled weekly schedules; at least one day enforced by the aggregate save transaction and domain type. |
| `task_occurrences` | `id`; `task_id` FK → tasks; immutable `scheduled_date` (normal slot identity); `effective_date` (after moving); paired nullable `start_minute`, `end_minute` (effective window copied from defaults at generation); nullable `reminder_minutes_before` (effective preference); `completed` default 0; nullable `completed_at_utc`; nullable `deleted_at_utc`; `is_schedule_exception` default 0; `revision`. Unique (`task_id`, `scheduled_date`). Pending requires null completion time; legacy done may have unknown time. Occurrence window/reminder checks match task defaults. |
| `task_subtasks` | `id`; `task_id` FK → tasks; nonblank `title`; nonnegative `position`; `active` default 1. Inactive definitions retain old state and are excluded from displayed totals. Active siblings have unique positions. |
| `task_occurrence_subtasks` | `task_id`; `occurrence_id`; `subtask_id`; `completed` default 0; primary key (`occurrence_id`, `subtask_id`). Composite foreign keys (`task_id`, `occurrence_id`) and (`task_id`, `subtask_id`) reference corresponding unique ownership keys on occurrences and subtask definitions. Both records MUST belong to the same task. A missing state row means pending. |
| `tags` | `id`; nonblank display `name`; nonblank unique `normalized_name` produced by `TagName` normalization. |
| `task_tags` | `task_id` FK → tasks; `tag_id` FK → tags; composite primary key. Removing a task-tag link MUST NOT delete a tag used elsewhere. |
| `calendar_participants` | Existing `id`, `name` records retained. No participant creation or profile schema is introduced. |
| `task_participants` | `task_id` FK → tasks; `participant_id` FK → calendar_participants; composite primary key. Migrated from existing entry links; inherited by a task's occurrences. Editor writes preserve these links. |

Task-owned child foreign keys use `ON DELETE CASCADE` for an explicit future
physical cleanup; participant/tag links cascade on removal of their referenced
entity, never into other tasks. This feature's Delete command only sets an
occurrence tombstone. No physical purge is scheduled. Tombstones are necessary
to prevent recurrence from recreating a deleted date after Undo expires.

The relational contract MUST also enforce declared maximum text lengths,
nonblank normalized names, valid date shape, valid minute/enum ranges, and
cross-field reminder/completion checks where expressible. Exact Unicode
character counting and tag normalization MUST be identical between domain and
persistence validation; the plan MUST define and test their shared semantics.

Index visible occurrence reads by `effective_date` and deletion/completion
status, lookup/streak/recurrence reads by (`task_id`, `scheduled_date`), and
participant lookup by (`participant_id`, `task_id`). Use set-based range reads
for cards and child summaries rather than one query per card.

### Recurrence and persisted state

- Ensure only requested calendar intervals plus today's agenda; do not eagerly
  materialize an infinite series. A recurrence use case resolves matching
  `LocalDate`s and asks the repository to insert missing slots transactionally.
  Repeated or concurrent generation is safe under the unique slot key.
- Read effective dates for agenda placement and original scheduled dates for
  duplicate prevention and streaks. Materialization MUST include original slots
  matching the requested interval as well as moved-in existing occurrences.
- Streak calculation compares recorded completions against scheduled daily
  dates from the effective daily start; missing rows represent uncompleted
  dates, not storage errors. It does not need to create every historical slot.
- Preserve completed/moved/deleted protected slots during recurrence edits.
  Remove only untouched pending future slots being replaced, then ensure the
  newly requested range under the current rule in the same mutation boundary.
  A shared task revision prevents a concurrent generator using the old rule
  from committing after a schedule edit.
- Shared task content and active checklist definitions are canonical on tasks;
  effective window/reminder and completion belong to occurrences. Updating
  defaults changes untouched future occurrences; protected instances keep
  their effective schedule. The selected edited instance gets its explicit
  window/reminder as an exception. This separation MUST be visible in editor
  scope guidance and covered by tests.
- Undo uses an action token containing occurrence identity, prior state, and
  resulting task/occurrence revisions. Undo conditionally restores that state
  in one transaction. Tokens are short-lived application state; persisted
  domain records and tombstones remain authoritative across restarts.

### Migration, compatibility, and rollback

The current implementation has migrations `0001` through `0003`,
`calendar_entries(id, title, date, cadence, completed)`,
`calendar_participants`, and `calendar_entry_participants`. Migration history
and `user_version` are already maintained together by the initializer.

The next migration is
`migration_0004_create_task_tables.dart` /
`Migration0004CreateTaskTables`, registered as `0004_create_task_tables`. If
another migration lands first, use the next consecutive number without
renaming any applied migration.

The new migration MUST:

1. Create the canonical task tables and constraints within the existing
   migration transaction; leave migrations 0001–0003 unchanged.
2. Map each legacy entry to a task and occurrence, using its existing entry ID
   as both task ID and occurrence ID in their separate identity namespaces.
   Preserve title, date, cadence, and completion; set original/effective dates
   to the original date, recurrence disabled, priority low, no time/reminder,
   and no invented completion or creation timestamp. Preserve example labels.
3. Copy every participant association to `task_participants`, preserving the
   participant records and existing ID values. Validate migrated row/link
   counts and all foreign keys before removing the superseded entry/link
   tables. Abort the migration if a legacy record cannot be represented.
4. Switch CalendarDatabase reads to joins/projections of the canonical tables
   as part of the same feature release. The old calendar tables MUST NOT remain
   independently writable or serve as a second source of truth.
5. Record the migration and new version only after successful transformation;
   failure rolls back schema, records, and history together. Fresh installs
   still run the existing once-only seeder and then migrate its examples;
   upgrading MUST NOT reseed or expand examples.

Before release, verify upgrade from fresh, legacy version 1, and the current
version 3 database, including existing completion and participant data.
Previously applied history identifiers MUST remain unchanged.

A failed migration rolls back automatically. A downgrade after successful use
is lossy because the old schema cannot represent recurrence, subtasks, tags,
or recovery state. Do not implement an automatic destructive down migration or
open a newer schema with an older application. Operational rollback requires
stopping the app and restoring a pre-upgrade backup with its matching app
version; preserve/export post-upgrade data before any deliberate conversion.
The app MUST NOT reset storage to recover from a migration error.

### Proposed application contracts and failures

Use the following domain-oriented boundaries; exact Dart
signatures and result types will be settled in the approved plan.

| Operation | Inputs and successful output | Explicit failure states |
| --- | --- | --- |
| `SaveTask` | Validated draft, selected occurrence, expected revisions; committed task/occurrence identities and affected dates. Saves task, tags, checklist, and schedule changes atomically. | Validation failure, not found/deleted, stale revision, storage unavailable. Overlap is advisory, not failure. |
| `EnsureTaskOccurrences` | Local date interval; persisted missing slots and a range snapshot after generation. | Invalid range, stale schedule/retry, storage unavailable. Unique-slot collisions resolve as existing slots. |
| `CalculateDailyStreak` | Task's enabled daily schedule, completion history, injected today; nonnegative streak. Pure domain calculation. | Not applicable when tracking is disabled or cadence is not daily; unavailable history is not a zero streak. |
| Complete / Reopen | Occurrence ID, expected task/occurrence revisions, injected clock; committed state plus recoverable prior state for completion. | Not found/deleted, stale revision, storage unavailable; already-target-state is an idempotent success. |
| Postpone | Pending occurrence ID, expected revisions, injected local today; moved occurrence and affected dates. | Already completed, not found/deleted, stale revision, storage unavailable. Already tomorrow is a no-op. |
| Delete / Undo | Occurrence ID or current action token, expected revisions; tombstoned/restored occurrence and affected dates. | Not found, stale state, expired/replaced token, storage unavailable. |
| TaskRepository reads/writes | Domain aggregates, range snapshots, checklist/completion history; atomic conditional mutations and post-commit change notifications. | Explicit domain conflicts/not-found; infrastructure failure translated to a presentation-safe unavailable result at the application boundary. |
| TaskDatabase operations | Parameterized range/aggregate queries, transactional inserts/updates/tombstones, migration mapping. Return rows/write outcomes only to repositories. | Constraint, connection, migration, and transaction failures; never leak SQL or task content to UI/logs. |

### Validation obligations for the subsequent plan and tasks

The implementation agent MUST read the constitution, architecture, conventions,
design reference, ADR 0001, this approved specification, and the calendar spec
before touching production code.

Use Red-Green-Refactor: demonstrate a failing test for the next specified
behavior, implement its minimum solution, then refactor while preserving the
behavior. The plan and checklist MUST cover:

- Domain tests for validation, daily/weekly dates, recurrence edit protection,
  streak gaps/backfill, time overlap, completion/subtask independence, and
  calendar arithmetic at month/year/leap-day boundaries.
- Real SQLite tests for upgrade preservation, all relevant constraints,
  rollback during aggregate child writes, stable slot identity/tombstones,
  conditional writes/Undo, concurrent recurrence generation, and history/version
  consistency. Repository fakes are suitable for presentation tests.
- ViewModel/widget tests for the four card variants and editor states, menus,
  draft discard, exact swipe boundary/cancellation, keyboard alternatives,
  Undo expiry/focus, localization, responsive/keyboard layouts, and safe errors.
- Integration checks that Today, calendar entries/indicators/counts, and
  streaks refresh after writes, and that task state survives restarting.
- Manual matching-viewport comparison with both Stitch exports, including the
  modal's initially scrolled-off time, recurrence, and checklist sections.
- `dart format .`, `flutter analyze`, and `flutter test` from `app/`, with all
  existing checks passing, synchronized documentation, and no known
  constitution violation before implementation is complete.

Native local persistence uses the existing database lifecycle. Web persistence,
authentication, remote authorization, sync, storage encryption, and notification
delivery are not introduced. Persisted/input data is untrusted; diagnostic
context MUST exclude titles, notes, tag names, and participant names. Reads are
bounded by the visible interval; recurrence MUST NOT perform unbounded future
generation or one database query per card. No numeric latency target is
invented by this specification.

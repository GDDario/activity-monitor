# Task Types, Custom Fields, and Progress Metrics

Interview date: 2026-11-19

Status: Interview stopped at the user's request after Q26. The decisions below
were accepted by the user. This document records the interview results; it is
not an implementation specification or authorization to implement the feature.
Unresolved details are listed at the end.

## Purpose

Allow users to track different kinds of tasks with suitable icons, setup forms,
activity logging controls, and progress metrics. Provide built-in task types and
let users create custom types with configurable fields.

## Task types and organization

- **Q1:** Each task has one type. The type defines its fields and controls.
  Context tags remain a separate, existing concept.
- **Q5:** Read and Exercise are grouping headings. Book, Comic, Gym, and
  Calisthenics are selectable types beneath them. Study, Work, Watching series,
  and Cleaning are directly selectable types.
- **Q10:** Tasks may use a General type with the existing controls and no
  additional fields. Existing tasks use General initially.
- **Q11:** Users can create standalone custom types or place them under a
  grouping heading. Initially there is one grouping level. Each type defines
  its own fields; a shared heading does not imply shared fields.

Each type has an appropriate icon, such as a book for Book tasks. Selecting a
type changes both the task setup form and activity logging controls (**Q2**).

## Built-in types and availability

- **Q4:** Built-in defaults cannot be edited by users.
- **Q8:** Users can hide built-in types from the picker. Existing tasks retain
  their type when it is hidden.
- **Q9:** Defaults become available after offline local profile setup and to
  existing users after upgrading. Online account creation is outside this
  feature. This aligns the original request for account-creation defaults with
  the application's current local-profile model.
- **Q15:** When the app introduces a new built-in type, users receive a
  dismissible in-app notice. The user's reference to a new task appearing was
  clarified to mean a new built-in type, not an assigned task.

The initial built-in tracking models accepted in **Q17** are:

| Group | Type | Tracking model |
| --- | --- | --- |
| Read | Book | Total pages and current page per session |
| Read | Comic | Total issues or volumes and completed units per session |
| Exercise | Gym | Exercises, sets, repetitions, weight where relevant, and duration |
| Exercise | Calisthenics | Exercises, sets, repetitions, weight where relevant, and duration |
| — | Study | Session duration and notes |
| — | Work | Session duration and notes |
| — | Watching series | Seasons, episodes, and recorded watched episodes |
| — | Cleaning | Item checklist, session duration, and notes |

Additional built-in types remain to be defined.

## Custom types and fields

- **Q3:** Users create custom types from supported fields, and the app generates
  their forms. Basic field kinds are text, numbers, dates, checkboxes, and
  choices. Built-in types use the same capabilities wherever possible.
- **Q6:** Fields belong either to the task definition or to individual activity
  logs. Custom-type creation exposes that distinction. A book's total pages
  belong to the task; session progress belongs to its logs.
- **Q18:** Custom types also support reusable structured field options for
  exercise sets, episode lists, and checklists. These have predefined controls
  that users configure rather than requiring users to design menus.
- **Q24:** Editing a custom type affects future entries. Historical logs retain
  the field names, units, and values used when recorded. Removing a field
  retires it from new forms without deleting history. Changing a field's kind
  or unit creates a replacement field so incompatible measurements are not
  silently combined.

## Task details, logs, and metrics

- **Q12:** Opening a task shows a progress summary, a Record progress action,
  and log history. A separate dashboard combining multiple tasks can come
  later.
- **Q13:** Users can record multiple sessions for the same task on one day,
  enter past sessions, and edit or delete mistaken entries. Logging sessions
  remains separate from completing a dated task occurrence.
- **Q16:** Numeric fields support total, latest value, average, or highest value
  summaries, with optional units and targets, plus charts over time. Text,
  choices, and checkboxes remain visible in logs.
- **Q26:** A task may designate one numeric metric as its main progress target
  for the summary and finish-date pace calculation. Other metrics still have
  summaries and charts. Initial pace calculations apply only to additive
  progress toward a known total, such as pages read.

Logs supply the measurements; the task detail screen presents both those
individual records and their summarized metrics.

## Type-specific progress behavior

### Books

**Q19:** Readers enter the page they reached. The app derives pages read from
the previous entry. Starting midway through a book establishes a baseline
without counting earlier pages as newly read. Corrections and backdated entries
recalculate affected metrics. Additional reading from rereading earlier pages
needs a separate recording mechanism; that mechanism was not defined.

### Comics and series

**Q20:** Users explicitly mark numbered issues, volumes, or episodes as
completed. Gaps and out-of-order consumption are supported. Comic tasks choose
issues or volumes as their tracking unit. Series organize episodes by season.
Entry is manual initially; external catalog lookup is a separate feature.

### Workouts

**Q21:** Each workout task contains a reusable exercise routine copied into each
session. Users can adjust exercises and record sets independently within that
session. Routine changes affect future sessions while preserving past workouts.

### Duration

**Q22:** Duration fields support start/stop timers and manual entry. Only one
timer runs across the app at a time. A running timer survives closing the app,
and users can correct the recorded duration.

## Scheduling, targets, and completion

- **Q7:** Recording progress does not automatically complete a task occurrence.
  Completion remains under the user's control.
- **Q14:** Tasks may have a desired finish date separate from their schedule.
  Where measurable progress supports it, the app suggests a pace, such as
  “240 pages remaining; about 12 pages per day to finish by December 10.”
  Missing that target does not automatically mark failure or complete the task.
- **Q25:** An explicit Finish task action is separate from completing today's
  occurrence. It stops future occurrences and preserves history. Users can
  reopen a finished task. Reaching the final page or episode can suggest
  finishing, but finishing still requires the user's action.

## Changing a task's type

**Q23:** Users can change a task's type after a warning. Previous logs retain
their original fields, while future entries use the new type. Metrics from
incompatible fields remain separate.

## Unresolved details

The interview ended before these details were settled. They are follow-up
design questions, not accepted requirements:

- Exact forms, icons, navigation, chart presentation, and field validation.
- Required versus optional fields, choice configuration, and numeric precision.
- How users record rereading and how it affects progress versus reading volume.
- Treatment of duplicate completed units, repeat viewing, and changing totals.
- Checklist reset behavior across sessions and task occurrences.
- Workout metric calculations and structured-field summary options.
- Timer pause behavior and elapsed-time handling after an app restart.
- Pace calculation rules, including eligible days and overdue targets.
- Custom-type renaming, hiding, deletion, and grouping management.
- Migration and compatibility rules when built-in definitions change.
- Log attribution and permissions for shared tasks.
- Detailed acceptance criteria and reconciliation with existing task,
  recurrence, profile, and completion specifications.

Before implementation, translate the agreed behavior into the project's
specification workflow and resolve the details needed for the chosen scope.

# SECTION 1: SPEC

## One-line purpose

Help users understand today's progress and choose their next activity through a
calm overview and a grouped agenda backed by their saved tasks.

## Status and sources

**Approved.** The user approved this specification and decisions H01–H07
in response to the explicit request to review those assumptions and approve the
specification. Issue [#7 — Home screen](https://github.com/GDDario/activity-monitor/issues/7)
was implemented on `feature/7-home-screen` after plan approval. Current
acceptance evidence and completion tracking are recorded in [tasks.md](tasks.md).

Sources:

- [Constitution](../../project/constitution.md),
  [architecture](../../project/architecture.md),
  [conventions](../../project/conventions.md), and
  [design reference](../../project/design-reference.md).
- [Application foundation](../FEATURE%201%20-%20application%20foundation/spec.md):
  Today entry point, common header, existing destinations and unavailable
  notifications behavior.
- [Tasks](../FEATURE%203%20-%20tasks/spec.md): saved occurrences, Today date
  semantics, filters, task actions, shared recovery feedback and durability.
- [Calendar](../FEATURE%202%20-%20calendar/spec.md): independent date navigation.
- Stitch [Today HTML](../../../../.scratches/stitch_shared_activity_tracker/today_tasks_activities/code.html)
  and [image](../../../../.scratches/stitch_shared_activity_tracker/today_tasks_activities/screen.png).

Tasks #10 passed a fresh 358-test suite, visual review and Android build before
this feature was started. It already provides working persisted Today tasks,
All/Solo/Shared filters, counts, creation and task actions. Home extends that
baseline; it MUST NOT replace real data with the export's example content.

## Users and use cases

- As a user, I want to see my local day and actual completion progress so that
  I can orient myself without reviewing every task.
- As a user, I want to narrow today's activities to my solo work or companions
  so that I can understand the commitments relevant to my current context.
- As a user, I want tasks grouped by their scheduled part of the day so that I
  can find an activity without losing unscheduled or completed work.
- As a user, I want to create, edit and act on tasks from Home so that I can
  keep my schedule accurate without changing screens.
- As a user, I want usable empty, loading and unavailable states so that I can
  distinguish an unplanned day from a storage problem.

## Requirements

1. **REQ-HOM-001 — Entry point and identity:** Home MUST remain the existing
   Today destination and show the current local date, a short calm phrase,
   greeting, profile entry, Calendar access and notifications access.
   It MUST NOT invent a user name, photo, presence status or unread indicator.
   **H01 (approved):** use a time-based greeting without a name until a real local
   profile supplies one; morning is before 12:00, afternoon 12:00–17:59, evening
   from 18:00. Keep the existing neutral avatar until Profile provides data.
2. **REQ-HOM-002 — Due-today data:** The agenda MUST contain nondeleted saved
   occurrences whose effective local date is today, including completed tasks.
   Recurrence, exceptions and migrated tasks MUST retain Tasks' approved
   semantics. Moving an occurrence away from today MUST remove it from Home.
3. **REQ-HOM-003 — Filters:** All activities, Solo and Shared MUST remain
   reachable with the established Calendar-compatible selected/unselected colors.
   The selection MUST be visible and accessible. Companion filters MUST use
   actual associated identities, never the export's sample people.
   **H02 (approved):** add one chip per distinct companion associated with today's
   tasks; choose exactly one scope among All, Solo, Shared or a companion.
   Companion selection includes any task associated with that identity. All is
   the initial/reset scope. Preserve the scope across refreshes and navigation
   during the session; if a selected companion disappears from today's data,
   reset to All. Do not persist filter selection across restarts.
4. **REQ-HOM-004 — Rhythm summary:** Home MUST show the reference's Rhythm of
   the Day hierarchy: completed/total, readable percentage and progress ring,
   concise remaining-work feedback, next scheduled activity and collaborative
   count. All figures MUST derive from the same available task set as the agenda.
   **H03 (approved):** summary values follow the active filter. Total counts
   occurrences, completed counts completed occurrences, and the displayed
   percentage rounds completed / total × 100 to the nearest integer. Zero tasks
   shows 0 of 0 and 0%, with empty-day guidance; a fully completed set shows 100%
   and calm completion feedback. Collaborative counts occurrences with at least
   one companion, including completed occurrences, counting each occurrence once.
   Remaining work counts pending occurrences; do not call these focus blocks.
5. **REQ-HOM-005 — Next activity:** The next-activity label MUST display only
   real pending schedule information and MUST update as the day progresses.
   **H04 (approved):** choose the earliest pending visible occurrence with a
   specific start time at or after the current local minute. Exclude untimed,
   completed and earlier-started tasks from Next while retaining them in the
   agenda. Break equal-time ties by the existing stable task ordering. When none
   qualifies, show a localized no-upcoming-scheduled-task label. Reevaluate at
   minute boundaries, on resume, after filtering and after committed changes.
6. **REQ-HOM-006 — Agenda groups:** Home MUST retain the export's editorial
   section headings and data-backed group counts. Every visible occurrence MUST
   appear exactly once; grouping MUST NOT hide tasks without a time.
   **H05 (approved):** use Morning Focus for starts before 12:00, Afternoon &
   Evening for starts from 12:00, and Any time for tasks without a specific
   window or daily day-period preference. For an untimed daily task, its saved
   morning/afternoon/evening preference selects the matching group. A specific
   start time takes precedence over that preference. Hide empty groups. Within
   each group, put pending before completed, timed tasks by start time, then
   untimed tasks, then the existing title/identity tie-breakers. This replaces
   Today's flat status-first ordering; Calendar ordering stays as approved.
   The Tasks specification records this approved Home-specific ordering.
7. **REQ-HOM-007 — Cards and actions:** Task cards MUST retain Tasks' shared
   status meanings, completion/reopen, edit, postpone, delete, swipe and Undo
   behavior. Saved optional metadata MUST be shown without invented values.
   The Home reference's notes preview SHOULD appear when notes exist.
   **H06 (approved):** add a maximum two-line notes preview on Home, with the full
   saved text available through Edit; preserve full accessible task titles and
   avoid introducing a separate details screen. Reuse the accepted task-card
   visual language where the Home export presents a different sample variant.
8. **REQ-HOM-008 — Creation and recovery:** The floating Create task action
   MUST open the existing personal editor with today's local date. Saving MUST
   refresh groups, counts, filters and Next from committed data. Undo MUST remain
   reachable above the floating action and preserve its remaining recovery
   window when navigating between Home and Calendar. Failure MUST retain the
   existing safe retry/conflict behavior rather than announce success.
9. **REQ-HOM-009 — Day and lifecycle changes:** Home MUST refresh after
   committed task changes, resuming on a different local day and local midnight.
   Old-day responses MUST NOT replace the new day's state. Calendar's explicit
   selected date MUST remain independent from Home's current day.
10. **REQ-HOM-010 — Availability:** Loading, an empty day, an empty filtered
    result and unavailable data MUST remain distinct. Unavailable data MUST show
    a safe retry action and MUST NOT present old counts as current or substitute
    examples. Zero matching results MUST provide a reachable All/reset action.
11. **REQ-HOM-011 — Localization and accessibility:** All new dates, greetings,
    headings, plural counts, feedback, filter names and percentages MUST support
    en-US and pt-BR. Controls MUST have meaningful names, visible keyboard focus
    and targets of at least 48 × 48 logical pixels. Progress MUST have a text
    equivalent. Essential content MUST remain reachable at 320 logical pixels,
    doubled text and wide layouts, without being hidden by keyboard, navigation,
    floating creation or recovery feedback. Reduced motion MUST be respected.
12. **REQ-HOM-012 — Scope and visual continuity:** Home MUST follow the supplied
    header/filter/summary/grouped-agenda hierarchy, forest colors, warm neutral
    surfaces, editorial headings, restrained separators and whitespace. Existing
    working navigation and task mutations MUST remain available.
    **H07 (approved):** keep the existing Today, People, Calendar and Profile
    destinations and shared navigation treatment; do not add the export's Tasks
    or Insights destinations. Focus timers, focus-session history, invitations,
    synchronization, profile editing, notification delivery and new collaboration
    workflows remain separate features. The export's decorative presence/unread
    dots and fake portraits are omitted until backed by actual features.

## Business rules

- An occurrence is counted and grouped by its effective local date, not its
  task definition's original start or recurrence label.
- Domain and persistence invariants remain owned by Tasks; Home owns the
  presentation of the daily overview and MUST NOT maintain a second completion
  state or store a derived summary as independent truth.
- Progress, group totals and the filtered agenda MUST describe the same
  occurrence identities. A task associated with multiple companions is still
  one occurrence, and repeated titles do not identify the same occurrence.
- Local calendar dates and saved wall times retain existing travel/time-zone
  semantics. Displayed completion instants use the current locale/time zone.
- A refresh, filter or navigation operation MUST NOT mutate task data. Failed
  operations MUST preserve persisted records and avoid exposing private task
  content or technical errors in diagnostics.

## Edge cases

| Situation | Expected behavior |
| --- | --- |
| No tasks exist today | Zero summary, useful empty-day guidance and enabled creation after successful load. |
| A scope has no matching tasks | Zero filtered summary, clear-filter action; other tasks remain stored. |
| All matching tasks are complete | 100%, completion feedback, no Next entry; reopen remains available. |
| Only untimed or earlier-started pending tasks remain | Keep tasks visible, show no upcoming scheduled task. |
| Equal times, repeated titles or multiple companions | Stable ordering, separate occurrence identities and no inflated totals. |
| A task moves across noon or midnight | Recompute its group/day membership only after successful persistence. |
| One companion disappears following a task change | Apply the reviewed H02 fallback consistently to filters and summary. |
| Storage fails during load or refresh | Safe unavailable state with retry; no fabricated or stale current metrics. |
| The day changes during an outstanding load | Ignore old responses; show the current local day when loading completes. |
| Long names, notes and doubled Portuguese text | Wrap/scroll essential content; preserve accessible labels and fixed actions. |
| Unknown profile or no notification capability | Neutral identity and existing unavailable notification feedback. |

## Acceptance criteria

- **AC-HOM-001 — Real day and identity:** Given the device's local date/time and
  no saved profile, when Home opens, then it shows that date and the reviewed
  greeting fallback without Alex, invented photos, presence or unread counts.
- **AC-HOM-002 — Saved occurrences:** Given pending, completed, deleted,
  postponed and tomorrow occurrences, when Home loads, then it shows exactly
  today's nondeleted effective-date occurrences and preserves their identities.
- **AC-HOM-003 — Scope filters:** Given solo tasks and tasks associated with
  two real companions, when each scope is selected, then the visible occurrences,
  group totals, summary and selected semantics follow H02–H03 without duplicates.
- **AC-HOM-004 — Progress:** Given four completed occurrences among seven
  matching occurrences, when their summary appears, then it reads 4 of 7 and
  57%, with three pending and the correct collaborative occurrence count.
- **AC-HOM-005 — Zero and complete:** Given zero tasks or a fully completed
  nonempty set, when Home renders, then it respectively shows 0%/empty guidance
  or 100%/completion feedback without division errors or invented Next entries.
- **AC-HOM-006 — Next activity:** Given earlier, future, completed and untimed
  activities, when time advances or filtering/completion changes the candidates,
  then Next follows H04 and refreshes without changing task completion.
- **AC-HOM-007 — Group boundaries:** Given 11:59, 12:00, untimed preferred and
  untimed unclassified tasks, when Home renders, then each appears once in its
  H05 group, with correct counts and ordering.
- **AC-HOM-008 — Existing mutations:** Given a visible occurrence, when the
  user completes/reopens, edits, postpones or deletes it, then existing Tasks
  persistence/error behavior holds and Home/Calendar update consistently.
- **AC-HOM-009 — Creation:** Given a loaded Home, when Create task is opened
  and a valid task is saved, then today's date is the default and the saved
  occurrence appears in the corresponding group and summary without restart.
- **AC-HOM-010 — Recovery across navigation:** Given an active task Undo
  window, when the user navigates Home → Calendar and undoes, then the same
  committed action is recovered within its remaining window and both screens
  reflect the result.
- **AC-HOM-011 — Refresh and day rollover:** Given a selected scope and an
  outstanding old-day load, when midnight/resume changes the day, then old data
  cannot replace new data and Calendar's explicit selection is retained.
- **AC-HOM-012 — Unavailable and retry:** Given storage failure, when Home
  loads and subsequently retries successfully, then safe unavailable feedback
  becomes current real data without database reset, fake tasks or action replay.
- **AC-HOM-013 — Empty filtered result:** Given a loaded nonempty day and an
  empty matching scope, when All/reset is activated, then all today's tasks and
  matching counts reappear without a write.
- **AC-HOM-014 — Visual and accessible delivery:** Given each supported locale,
  compact/wide screens and doubled text, when Home and its task actions are
  rendered and operated by keyboard/assistive technology, then essential labels,
  groups, summary, creation and Undo remain reachable and meaningful. Fresh
  matching-viewport captures MUST be compared with the Stitch HTML/image.

## Reviewed decisions

All seven decisions were approved with this specification; none remains pending.
Their identifiers are retained for traceability in the plan and future checklist.

| Decision | Accepted behavior |
| --- | --- |
| H01 | Time-based neutral greeting; existing avatar until real profile data exists. |
| H02 | Exclusive All/Solo/Shared/companion scope; retain for the session; fall back to All when a companion disappears. |
| H03 | Filtered occurrence-based summary, rounded percentage and real remaining/collaborative counts. |
| H04 | Next is the earliest pending start at or after the current local minute; reevaluate on time and state changes. |
| H05 | Morning, afternoon/evening and any-time groups; pending-first ordering inside each group; Calendar unchanged. |
| H06 | Optional two-line Home notes preview with full text through Edit; accepted shared task-card behavior. |
| H07 | Preserve current destinations; focus timers and new collaboration/profile/notification workflows remain outside this delivery. |

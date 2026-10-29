# Responsive view separation

The Stitch screens are strong mobile references, but they combine some workflows that should become separate routes or adaptive panes in a production app. This document proposes the presentation boundaries; it does not define domain behavior.

## Application shell

| Window width | Navigation | Content behavior |
| --- | --- | --- |
| Compact: under 600 | Floating/standard bottom navigation | One primary route at a time; creation and editing open full-screen pages or bottom sheets. |
| Medium: 600–1023 | Navigation rail | A primary list may remain visible while detail opens in a pane or route. |
| Expanded: 1024+ | Persistent navigation rail, optional contextual side pane | Center content is bounded; lists and selected-detail panes can coexist. |

Primary destinations: **Today**, **Activities**, **Focus**, **People**, and **Insights**. Settings and global search are shell actions rather than primary destinations.

## Today

Source: `today_tasks_activities`.

- `TodayView`: daily progress, next activity, focus prompt, and grouped activity preview.
- `ActivityPreviewCard`: compact reusable card used by Today and search results.
- `TodayFiltersBar`: date, solo/shared, person, and status filters.

On compact layouts this is a vertically scrolling summary. On expanded layouts it becomes a two-column work surface: timeline/activity stream in the main column and daily progress plus upcoming focus sessions in the contextual pane.

## Activities

Source: task cards from `today_tasks_activities` and the edit screen.

- `ActivityListView`: filters, grouping, list/grid selector, and activity results.
- `ActivityDetailView`: read-only description, schedule, participants, tags, history, and focus sessions.
- `ActivityEditorView`: create/edit activity form. It must not be embedded permanently inside the list.
- `ParticipantPicker`: reusable modal or side pane used by the activity editor.
- `ChecklistEditor`: reusable section within the editor.

On a phone, opening an activity is a route and editing is a full-screen editor. On desktop, `ActivityListView` and `ActivityDetailView` may be a master-detail split; editing opens a bounded dialog or side sheet to preserve list context.

## Focus

Source: `focus_activity_timer`.

- `FocusHomeView`: current/next session and schedule overview.
- `FocusSessionView`: distraction-reduced timer, session controls, participants, and active activity context.
- `FocusScheduleView`: calendar/date selection and scheduled-session list.
- `FocusSessionSummaryView`: completion reflection and log attribution.

The timer needs its own route so a phone can prioritize the clock and controls. On wide windows, the schedule and selected session can share a split layout, but the active timer remains a focused, bounded central surface.

## People

Source: `people_directory`.

- `PeopleDirectoryView`: search, filters, aggregate counts, and people list/grid.
- `PersonDetailView`: profile, relationship/category, shared activities, and activity history.
- `PersonEditorView`: create or edit person.

On compact layouts creation is a bottom sheet or route. On expanded layouts, the directory remains on the left and the selected person is shown in a detail pane; creation uses a side sheet.

## Insights

Not pictured in the Stitch reference, but required by its navigation.

- `InsightsOverviewView`: trends, activity mix, focus time, and collaboration summary.
- `InsightDetailView`: an accessible, filterable explanation of one metric.

Charts must always have textual summaries and table/list alternatives. This route should not be added to the initial UI preview until its data semantics are specified.

## Shared presentation components

- `ActivityAppShell`: responsive navigation and bounded content layout.
- `ActivityCard`, `MetricCard`, and `SectionHeader`: shared paper-like surfaces.
- `StatusChip`, `PriorityChip`, `PersonAvatar`, and `ParticipantStack`: semantic status and people representations.
- `FilterChipBar`: horizontal compact layout and wrapping/toolbar wide layout.
- `PrimaryActionButton`, `QuietActionButton`, and `DestructiveActionButton`: consistent action hierarchy.
- `EmptyState`, `ErrorState`, and `LoadingState`: shared asynchronous-state presentation.

## State and ownership

Each route owns one ViewModel. Shared filters that affect multiple routes belong to a dedicated application-level state object only after a real cross-route requirement exists. Views render state and forward intent; they do not access repositories or services. The responsive shell changes layout only—it does not duplicate activity or people state.

# SECTION 1: SPEC

## One-line purpose
Let users explore their scheduled activities by date, cadence, and participant.

## Users and use cases
- As a user, I want to navigate and select dates so that I can inspect my schedule.
- As a user, I want to filter entries so that I can focus on relevant commitments.

## Requirements
1. REQ-CAL-001: The calendar MUST open on the current local date, identify the selected date, offer Today, and show a seven-column month grid including adjacent dates.
2. REQ-CAL-002: Month and week modes MUST preserve selection when switched; week mode MUST show the seven days containing selection. Previous and next MUST move by the active interval, keeping the day of month where possible and otherwise clamping it.
3. REQ-CAL-003: Selecting a date MUST select that date, including dates in an adjacent month. [ASSUMPTION: Weeks begin Sunday in en-US and pt-BR.]
4. REQ-CAL-004: The grid MUST indicate matching solo/habit, collaborative, and recurring entries with distinguishable indicators and a localized, readable legend.
5. REQ-CAL-005: The calendar MUST offer All Cadences, Daily Habits, Weekly, One-Time, and available participant filters. [ASSUMPTION: One cadence and at most one participant may be selected; cadence and participant criteria combine with AND; All Cadences resets cadence and selecting an active participant clears it.]
6. REQ-CAL-006: The calendar MUST show matching entries for the selected day and an informative empty or unavailable state; counts MUST be derived from matching data. Task details and actions are out of scope.
7. REQ-CAL-007: Date labels and controls MUST support en-US and pt-BR, accessible names and selected states, keyboard focus, compact and wide layouts, and increased text size.
8. REQ-CAL-008: Entries and participant filters MUST come from durable local data when available; no sample entries or fabricated counts may be presented as user data. [ASSUMPTION: Only explicitly stored occurrences are displayed; recurrence expansion and collaboration synchronization belong to later features.]
9. REQ-CAL-009: Application startup MUST initialize local storage and apply pending schema migrations without requiring calendar navigation. A storage failure MUST NOT be treated as an empty calendar, and MUST NOT erase existing data.

## Business rules
- A calendar entry belongs to one local date and one cadence: daily, weekly, or one-time. Recurring means daily or weekly.
- An entry is collaborative when it has participants; otherwise it is solo. Participant filtering matches assigned participants.
- Filtering applies to both indicators and selected-day entries. Empty data and unavailable storage are distinct.

## Edge cases
- Navigation across month/year boundaries, leap days and short months clamps the selected day where needed.
- Weeks can span months and years; adjacent dates are selectable.
- No matching entries shows an empty state; data failure shows an unavailable state without technical details.

## Acceptance criteria
Given the calendar opens, when it renders, then today is selected and the current month is shown.

Given a selected date, when the mode changes, then that date remains selected and visible.

Given January 31, when navigating to February, then the final February date is selected, including February 29 in leap years.

Given matching entries, when cadence and participant filters are selected, then only entries satisfying both are shown and represented in the grid.

Given no matching entries or unavailable data, when the calendar renders, then it displays the corresponding localized state without fabricated counts.

Given a fresh installation, when the application starts, then its local database is created and the current schema is applied before calendar data is read.

Given a database with an existing supported schema, when the application starts again, then pending migrations are applied without losing existing data.

Given a migration fails or the database schema is newer than supported, when the application starts, then existing data is preserved and calendar data is reported unavailable.

Given either supported locale and a compact or wide viewport with enlarged text, when using the calendar, then essential labels, focus, selections and controls remain accessible.

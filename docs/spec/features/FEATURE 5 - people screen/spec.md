# SECTION 1: SPEC

> Delivery update (2026-11-18): after local validation, the user explicitly
> authorized committing and pushing each feature on its own issue branch. Earlier
> local-only restrictions below describe the implementation phase. People is
> delivered on `feature/8-people-screen`, based on `feature/7-home-screen`.
> Issue/project/PR mutations remain outside this authorization.

## One-line purpose

Help users maintain their local companions and find the activities they have
planned or completed together.

## Status and sources

Specification approved by the user ('Looks good. continue.'). The subsequent
'Continue, dont stop' instruction authorized proceeding with the proposed scope
choices PEO01–PEO07 and implementation plan without further document gates. Local implementation and validation are complete;
acceptance evidence is recorded in [tasks.md](tasks.md). Issue #8 remains unchanged
on GitHub under the user's current instruction.
Issue #8, People screen, is Todo in the project export supplied by the user.
All work for this delivery remains local: no commits, pushes, issue changes,
project changes, or pull requests under the user's current instruction.

Sources:

- [Constitution](../../project/constitution.md) and
  [design reference](../../project/design-reference.md).
- [Application foundation](../FEATURE%201%20-%20application%20foundation/spec.md):
  existing People destination and shared navigation.
- User-supplied issue #1: search previous collaborations, sortable/pageable
  activity history, optional tags and last-activity indicators.
- [Tasks](../FEATURE%203%20-%20tasks/spec.md): saved occurrences, participant
  identities and associations, task mutations and completion semantics.
- [Home](../FEATURE%204%20-%20home%20screen/spec.md): companion scopes.
- Stitch [People HTML](../../../../.scratches/stitch_shared_activity_tracker/people_directory/code.html)
  and [image](../../../../.scratches/stitch_shared_activity_tracker/people_directory/screen.png):
  directory, search, overview, category filters, person cards and creation sheet.

The export supplies no additional body for #8. The scope choices below therefore
require review. The design's example identities, portraits, counts, presence,
focus status and notifications are not evidence of saved application data.

## Users and use cases

- As a user, I want to create and maintain companions so that shared activities
  refer to people I recognize.
- As a user, I want to search and filter companions so that I can find a person
  without scanning the directory.
- As a user, I want to inspect recent completed and upcoming shared activities
  so that I can understand our shared rhythm.
- As a user, I want to associate companions with tasks so that new people can
  participate in the application's existing local collaboration views.

## Requirements

1. **REQ-PEO-001 — Destination:** People MUST replace the existing placeholder
   within the current navigation. It MUST follow the reference's editorial
   heading, search, overview and rounded directory cards, with a reachable
   New Person action. Existing destinations and header actions MUST remain.
2. **REQ-PEO-002 — Real identities:** The directory MUST show saved people,
   including legacy participants and people without activities. Identity MUST
   remain stable across edits and restarts. No example people, fabricated
   presence or focus states MAY be inserted to populate the design.
3. **REQ-PEO-003 — Create and edit:** Users MUST be able to create a person and
   edit their name and optional metadata. Cancel MUST save nothing. Successful
   changes MUST survive reopening; failures MUST retain the draft for retry.
   [ASSUMPTION: PEO01 — this delivery supports local create/edit with a required
   trimmed name of 1–100 Unicode characters, optional role of at most 100
   characters, and zero or more categories from Work, Household, Creative and
   Family. Duplicate names are allowed; identity, not name, distinguishes people.
   Deletion/merging and photo import are deferred; avatars use name initials.]
4. **REQ-PEO-004 — Task associations:** Companion choices MUST use saved
   identities. Existing associations MUST survive unrelated task edits.
   [ASSUMPTION: PEO02 — extend the task editor with an optional multiple-person
   selector. Assignments belong to the task and apply to its occurrences,
   including saved history, matching existing participant semantics. They do
   not represent invitations, accounts, remote permissions or separate per-person
   completion. This explicitly extends the Tasks specification's former
   exclusion of participant assignment; that specification must be revised
   before implementation once this scope is approved.]
5. **REQ-PEO-005 — Search and categories:** Search MUST match saved names,
   roles and category labels without case sensitivity and with surrounding
   whitespace ignored. Search and the chosen category MUST combine by AND.
   Clearing both MUST restore the full directory. Category filters MUST expose
   selection accessibly. [ASSUMPTION: PEO03 — search uses substring matching,
   ignores diacritics, and treats an empty query as all people. Choose one
   filter from All, Frequent, Work, Household, Creative and Family. Frequent
   means at least three nondeleted completed occurrences associated with the
   person in the last 30 local calendar days, including today, based on effective
   dates; future dates never qualify. Search matches category labels in the
   active language.]
6. **REQ-PEO-006 — Overview:** Overview figures MUST state their time scope
   and derive from saved data. A task with several people MUST count once in
   overall shared-work totals. Zero denominators MUST show meaningful empty
   feedback, never an undefined percentage.
   [ASSUMPTION: PEO04 — Collaborators counts all saved people, independently of
   directory filters. Active Shared Tasks counts today's pending nondeleted
   occurrences with at least one person. Work Dynamic shows today's solo/shared
   proportions across all nondeleted occurrences, including completed ones,
   with whole percentages summing to 100. With no occurrences, show an empty
   bar and 'No activities today' rather than a fabricated ratio.]
7. **REQ-PEO-007 — Person cards:** Cards MUST show the saved name, optional
   role/categories, today's pending associated occurrence count, and last
   activity information or a truthful absence message. Missing optional fields
   MUST leave no empty separators. Opening a card MUST show that person's
   associated activities and preserve a way back to the directory.
8. **REQ-PEO-008 — History and order:** Person details MUST offer a sortable,
   pageable list of nondeleted associated saved occurrences with title, effective
   local date, optional time and completion status.
   [ASSUMPTION: PEO05 — default order is effective date/time descending; users
   can select ascending instead. Untimed items follow timed items on the same
   date; equal values use title then stable occurrence identity. Pages contain
   20 occurrences with Previous/Next and result range. The list includes past,
   present and already saved future occurrences without materializing unbounded
   recurrence. Changing person or sort resets to the first page. Last activity
   is the latest completed, nondeleted associated occurrence with effective
   date no later than today; it displays that date and title. It does not claim
   when a companion personally completed anything.]
9. **REQ-PEO-009 — Activity actions:** Selecting a history activity MUST use
   existing task editing and mutations, preserving completion, postponement,
   deletion, stale-write rejection and Undo guarantees. The directory, history,
   Home and Calendar MUST reflect successful changes without application
   restart. Person editing MUST NOT modify task dates or completion.
10. **REQ-PEO-010 — Query state:** Search, filter and directory position SHOULD
    survive returning from person details or another destination during the
    session. [ASSUMPTION: PEO06 — these preferences are session-only; returning
    to a person's details starts its history on page one. Refreshes preserve
    valid selections and clamp an out-of-range page after data changes.]
11. **REQ-PEO-011 — Data availability:** Loading, empty directory, no search
    results, no shared history and storage unavailable MUST be distinct states.
    Failures MUST offer Retry without presenting missing data as a successful
    empty result. Repeated save activation MUST NOT create duplicate people.
    Stale responses MUST NOT replace a newer search, person or refresh result.
12. **REQ-PEO-012 — Accessibility and localization:** All user-facing text,
    dates, plurals, validation and semantics MUST support en-US and pt-BR.
    Search, filters, cards, sorting, pagination, editor and task association
    controls MUST support keyboard use, visible focus and accessible names.
    Essential content MUST remain reachable at 320 logical pixels with doubled
    text size and with the software keyboard open; wide layouts MUST remain
    readable. Category/presence meanings MUST NOT depend on color alone.
13. **REQ-PEO-013 — Offline integrity:** Reads and authorized local changes MUST
    work offline. Existing identities, participant links and task data MUST
    survive upgrading and reopening. Partial writes MUST NOT be observable;
    conflicting writes MUST fail safely instead of overwriting newer data.
14. **REQ-PEO-014 — Delivery boundary:** This delivery MUST NOT send invitations,
    sync contacts, invent online status, or deliver notifications.
    [ASSUMPTION: PEO07 — omit the reference's notification toggle because delivery
    belongs to #15; omit photo selection and unsupported person actions instead
    of presenting controls that cannot perform their stated action.]

## Business rules

- A person identity owns its name, role and category memberships. Name equality
  MUST NOT merge identities. Legacy people start with no role/categories.
- Task participant membership belongs to the existing task identity. An
  occurrence associated with several people appears once in each person's
  history and once in aggregate occurrence totals.
- Deleted occurrences do not contribute to history or metrics. Reopening a
  completed occurrence removes its contribution to completed-history metrics;
  Undo restores the state dictated by the existing Tasks rules.
- Completion records describe local task state, not evidence of another
  person's actions or presence. Missing completion timestamps MUST NOT be
  synthesized; last-activity dates use the defined effective-date rule.
- Today and the 30-day window use the device's local calendar date. Metrics
  MUST refresh on date rollover and application resume.
- Category identity is independent of its translated label. Search/filter
  transformations MUST NOT rewrite saved names or metadata.

## Edge cases

| Situation | Expected behavior |
| --- | --- |
| Legacy participants with identical names | Separate stable cards; edits and selection target identity. |
| Newly created person has no tasks | Appears immediately with zero active tasks and no-history guidance. |
| Empty or overlong required name | Reject save with a localized field error; retain draft. |
| Long names, emoji, missing roles/categories | Readable wrapping and initials fallback without overflow. |
| Task includes multiple people | One history entry per occurrence per person, no doubled global totals. |
| Deleted/reopened/postponed occurrence | Refresh history, active counts and last activity using saved state. |
| History shrinks on last page | Clamp to a valid page or display the explicit empty state. |
| Storage failure during assignment or person save | No partial state; preserve draft and offer retry. |
| Midnight or resume after several days | Recompute today and frequency without resetting valid search/filter state. |
| Empty day or directory | No fabricated collaborators, activity counts or ratio. |

## Acceptance criteria

1. **AC-PEO-001:** Given legacy and newly created people, when People opens,
   then each saved identity appears once and optional absent metadata is omitted.
2. **AC-PEO-002:** Given valid person details, when Save succeeds and storage is
   reopened, then the same identity and metadata remain available.
3. **AC-PEO-003:** Given an invalid name or a canceled draft, when Save is
   rejected or Cancel is selected, then no person is created or modified.
4. **AC-PEO-004:** Given people with distinct names, roles and categories, when
   search and a category are combined, then only matching identities appear;
   clearing both restores all identities.
5. **AC-PEO-005:** Given completed occurrences inside and outside the defined
   30-day window, when Frequent is selected, then only people with at least
   three qualifying occurrences appear.
6. **AC-PEO-006:** Given a task associated with two people and a solo task,
   when today's overview is shown, then each occurrence contributes once and
   the displayed proportions agree with the saved occurrence set.
7. **AC-PEO-007:** Given no occurrences today, when the overview is shown, then
   active count is zero and Work Dynamic states that there are no activities.
8. **AC-PEO-008:** Given more than 20 associated occurrences, when a person is
   opened and pages/sort are changed, then all eligible entries are reachable
   without duplication or omission in the selected deterministic order.
9. **AC-PEO-009:** Given completed, reopened, deleted and future occurrences,
   when the last-activity label is calculated, then it identifies only the
   latest qualifying completed occurrence or states that none exists.
10. **AC-PEO-010:** Given saved people, when a task's participant selection is
    changed and saved, then person histories and Home/Calendar companion views
    reflect that membership after refresh and after storage reopening.
11. **AC-PEO-011:** Given an editable history entry, when an existing task action
    succeeds or is undone, then saved state and every affected People count
    refresh while existing task mutation guarantees remain satisfied.
12. **AC-PEO-012:** Given unavailable storage or overlapping reads, when retry
    succeeds or a newer response arrives, then current data is shown without
    partial writes, fabricated empty results or stale response replacement.
13. **AC-PEO-013:** Given retained search/filter state, when users navigate away
    and back or the local date changes, then valid selections remain and the
    date-dependent metrics reflect the current day.
14. **AC-PEO-014:** Given either locale, keyboard navigation, compact/wide views
    and 320-pixel doubled-text rendering, when every directory, detail and
    editor control is exercised, then essential content/actions remain readable,
    reachable and accessibly named without overflow.
15. **AC-PEO-015:** Given a supported existing database, when upgraded and
    reopened, then identities, task links, schedules and completion are preserved
    and the directory operates offline without remote side effects.

## Scope choices used for implementation

- **PEO01 (high):** local create/edit, fields and limits; initials only;
  no deletion/merging or imported photos.
- **PEO02 (high):** task editor multiple-person assignment, with task-wide
  historical membership semantics.
- **PEO03 (medium):** search normalization, fixed category filters and the
  three-completions/30-day Frequent rule.
- **PEO04 (medium):** global directory count and explicitly today-scoped
  occurrence metrics independent of search/filter.
- **PEO05 (high):** saved-occurrence history, effective-date last activity,
  ordering and 20-entry pagination.
- **PEO06 (low):** session-only directory state and page-reset behavior.
- **PEO07 (medium):** defer notifications and photos; omit unsupported controls.

The user instructed continued implementation ('Continue, dont stop') after
reviewing the specification and plan. These proposed choices are being used
under that instruction; no further document gate is pending for this delivery.

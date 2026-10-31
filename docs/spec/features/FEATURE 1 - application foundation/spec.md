# SECTION 1: SPEC

## One-line purpose

Provide a calm, accessible application foundation through which users can view
their daily rhythm and navigate to People, Calendar, and Profile.

## Users and use cases

- As an Activity Monitor user, I want the app to open at Today so that I can
  begin in my current activity context.
- As an Activity Monitor user, I want a clear, responsive interface so that I
  can use the same app on compact and wide windows.
- As an Activity Monitor user, I want to move between Today, People, Calendar,
  and Profile so that I can reach the part of the app that matches my need.
- As an Activity Monitor user, I want to complete, edit, focus on, or remove a
  planned activity so that my daily plan stays accurate.
- As an Activity Monitor user, I want to find collaborators and review our
  recent shared activity so that I can maintain shared routines.
- As an Activity Monitor user, I want to select a calendar day and see its
  activities so that I can review or manage another day's plan.
- As an Activity Monitor user, I want to update my profile and presentation
  preferences so that the app reflects my identity and is comfortable to use.

## Requirements

1. `REQ-FOUND-001`: The application MUST open at the Today destination.
2. `REQ-FOUND-002`: The application MUST provide application-wide navigation,
   localization, presentation feedback, and replaceable dependency composition.
3. `REQ-FOUND-003`: The application MUST support United States English and
   Brazilian Portuguese. `[ASSUMPTION: these are the only initial product
   locales.]`
4. `REQ-UI-001`: The application MUST use a consistent visual language for
   color, typography, spacing, surfaces, actions, and status.
5. `REQ-UI-002`: Interactive controls MUST have accessible labels, visible
   focus affordances, and status meaning that does not rely on color alone.
6. `REQ-NAV-001`: The application MUST provide reachable Today, People,
   Calendar, and Profile destinations and MUST visibly indicate the active
   primary destination.
7. `REQ-NAV-002`: Every primary destination MUST provide a common title area
   with the user's profile image or name abbreviation, a concise screen-specific
   phrase, calendar access, and notifications access. `[ASSUMPTION:
   notifications are a non-functional entry point until a notifications feature
   is specified.]`
8. `REQ-NAV-003`: Today MUST show a summary and list of the selected day's
   activities, including each activity's explicit completion state. The existing
   Today dashboard MUST remain visible while base routing is introduced.
9. `REQ-NAV-004`: A user MUST be able to mark an activity complete or
   incomplete and edit its user-editable details. `[ASSUMPTION: editable details
   are title, description, planned duration, scheduled time, tags, and
   collaborators.]`
10. `REQ-NAV-005`: Swiping an activity right MUST open focus-session setup with
    its planned duration prefilled; the user MUST be able to set a positive
    replacement duration. `[ASSUMPTION: right swipe is the focus direction.]`
11. `REQ-NAV-006`: Swiping an activity left MUST reveal a confirmed removal
    action. Removing an activity MUST unschedule it from the selected day and
    MUST NOT delete its definition. `[ASSUMPTION: removal is day-specific.]`
12. `REQ-NAV-007`: People MUST provide search and a sortable, pageable list of
    collaborators. Each result MUST show tags, a most-recent shared-activity
    indicator, and recent shared activities. `[ASSUMPTION: results initially
    sort by most recent shared activity, with 20 results per page.]`
13. `REQ-NAV-008`: Calendar MUST initially show a full-screen calendar with the
    count of planned activities for each displayed day. Selecting a day MUST
    open that day's daily activity experience.
14. `REQ-NAV-009`: Profile MUST support changing display name, profile image,
    theme (light, dark, or system), and language (Brazilian Portuguese or United
    States English). `[ASSUMPTION: profile images use device-provided media and
    are stored locally.]`
15. `REQ-NAV-010`: Primary navigation and content MUST remain accessible and
    usable on compact and wide windows without clipped essential content.
16. `REQ-NAV-011`: People, Calendar, and Profile MUST show a short, helpful
    empty-state description when no relevant data is available. `[ASSUMPTION:
    these destinations have no seeded user data in the base release.]`

## Business rules

- Navigation selection is presentation state and MUST NOT contain domain
  behavior.
- User-facing messages MUST be presentation-safe and MUST NOT expose technical
  or sensitive error details.
- Until data-backed activities are introduced, the existing Today preview is
  presentation-only and MUST NOT be represented as persisted user data.
- A scheduled activity's completion state belongs to its selected-day entry and
  MUST update that day's summary.
- A focus-session setup MUST reject non-positive duration.
- A calendar day count MUST equal its scheduled, non-removed activities.
- A person's last shared activity MUST be the most recent activity in which
  both the current user and that person participated.
- Theme and language preferences belong to the current user profile and MUST
  apply to later application presentation.
- Newly generated persistent entity identifiers MUST use UUID version 7.

## Edge cases

- An unknown in-app location MUST render a presentation-safe fallback.
- An unsupported device locale or invalid stored language preference MUST fall
  back to United States English; an invalid stored theme MUST fall back to the
  system theme. `[ASSUMPTION: this fallback order is acceptable.]`
- On narrow windows, navigation remains reachable; on wide windows, reading
  content remains bounded; increased text scale wraps metadata rather than
  clipping it.
- If no usable profile image or name abbreviation exists, the title area shows
  a neutral avatar. `[ASSUMPTION: profile name is optional during setup.]`
- If a non-current selected day has no activities, its daily experience shows a
  zero summary and empty state.
- If an activity has no planned duration, focus setup requires a positive value
  before it can start.
- Cancelling removal leaves the activity and completion state unchanged.
- A People query with no matches or an unavailable page shows a safe empty state
  without stale results.

## Acceptance criteria

```text
Given the application starts with no requested location
When it is built
Then Today is displayed through the application router with localization and a presentation-feedback host

Given the application is open on a compact or wide window
When the user selects Today, People, Calendar, or Profile
Then the selected destination is displayed and primary navigation identifies it as active

Given any primary destination is displayed
When the user views its title area
Then they see a profile image or abbreviation, a screen-specific phrase, calendar access, and notifications access

Given base routing is introduced
When the user opens Today
Then the existing dashboard presentation remains visible

Given an incomplete scheduled activity
When the user marks it complete
Then its completion state and daily summary update

Given an activity with a planned duration
When the user swipes it right
Then focus-session setup opens with that duration prefilled and permits a positive replacement duration

Given an activity shown for the selected day
When the user swipes it left and confirms removal
Then it is no longer scheduled for that day and remains available outside that day

Given collaboration records exist
When the user searches and sorts People
Then the paged results show matching collaborators with tags and shared-activity information in the chosen order

Given Calendar is open
When the user selects a day with a displayed planned-activity count
Then the daily activity experience opens for that day

Given the user saves a valid Profile change
When the change is applied
Then the updated name, image, theme, or supported language is reflected in application presentation

Given People, Calendar, or Profile has no relevant records
When the user opens it
Then it shows a short, helpful empty-state description
```

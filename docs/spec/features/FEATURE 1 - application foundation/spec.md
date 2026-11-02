# SECTION 1: SPEC

## One-line purpose

Provide a calm, accessible application foundation through which users can view
the existing Today dashboard and navigate to base People, Calendar, and Profile
screens.

## Users and use cases

- As an Activity Monitor user, I want the app to open at Today so that I can
  begin in my current activity context.
- As an Activity Monitor user, I want a clear, responsive interface so that I
  can use the same app on compact and wide windows.
- As an Activity Monitor user, I want to move between Today, People, Calendar,
  and Profile so that I can reach the part of the app that matches my need.

## Requirements

1. `REQ-FOUND-001`: The application MUST open at the Today destination.
2. `REQ-FOUND-002`: The application MUST provide application-wide navigation,
   localization, presentation feedback, and replaceable dependency composition.
3. `REQ-FOUND-003`: The application MUST support United States English and
   Brazilian Portuguese, including foundation-owned navigation labels, screen
   descriptions, title-area controls, and feedback. These are the only initial
   product locales.
4. `REQ-UI-001`: The application MUST use a consistent visual language for
   color, typography, spacing, surfaces, actions, and status.
5. `REQ-UI-002`: Interactive controls MUST have accessible labels, visible
   focus affordances, and status meaning that does not rely on color alone.
6. `REQ-NAV-001`: The application MUST provide reachable Today, People,
   Calendar, and Profile destinations and MUST visibly indicate the active
   primary destination.
7. `REQ-NAV-002`: Every primary destination MUST provide a common title area
   with the user's profile image or name abbreviation, a concise screen-specific
   phrase, calendar access, and notifications access. Notifications are a
   non-functional entry point until a notifications feature is specified.
   Selecting the profile image, abbreviation, or neutral avatar MUST open Profile.
   Calendar access MUST open Calendar. Notifications access MUST either be
   visibly unavailable or display a safe unavailable message.
8. `REQ-NAV-003`: The Today destination MUST retain its existing dashboard
   presentation while base routing is introduced.
9. `REQ-NAV-004`: People, Calendar, and Profile MUST initially provide a blank,
   helpful screen with a short description of its intended purpose.
10. `REQ-NAV-005`: Primary navigation and content MUST remain accessible and
    usable on compact and wide windows without clipped essential content.

## Business rules

- Navigation selection is presentation state and MUST NOT contain domain
  behavior.
- User-facing messages MUST be presentation-safe and MUST NOT expose technical
  or sensitive error details.
- The existing Today dashboard is presentation-only and MUST NOT be represented
  as persisted user data.
- Persistent user data, activity mutations, focus sessions, collaborator data,
  calendar activity counts, profile changes, and notification delivery are out
  of scope for this foundation feature.

## Edge cases

- An unknown in-app location MUST render a presentation-safe fallback.
- An unsupported device locale MUST fall back to United States English.
- On narrow windows, navigation remains reachable; on wide windows, reading
  content remains bounded; increased text scale wraps metadata rather than
  clipping it.
- A profile name is required for setup and app usage. Setup and profile data
  behavior belong to a future feature; this presentation-only foundation does
  not implement or enforce them. If no usable profile image or abbreviation
  is available to the title area, it shows a neutral avatar.

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
Then they see a profile image, abbreviation, or neutral avatar, a screen-specific phrase, calendar access, and notifications access

Given a primary destination title area is displayed
When the user selects the profile image, abbreviation, or neutral avatar
Then Profile is displayed

Given base routing is introduced
When the user opens Today
Then the existing dashboard presentation remains visible

Given the user opens People, Calendar, or Profile
When no feature-owned data behavior has been implemented
Then the destination shows a short description of its intended purpose

Given the device uses Brazilian Portuguese
When a foundation destination or its controls are displayed
Then foundation-owned labels, descriptions, and feedback are in Brazilian Portuguese

Given the device locale is unsupported
When the application starts
Then foundation-owned text falls back to United States English

Given a primary destination title area is displayed
When the user selects Calendar or Notifications
Then Calendar opens, or Notifications is visibly unavailable or displays a safe unavailable message, respectively

Given an unknown location is requested
When the router resolves it
Then a presentation-safe fallback is displayed

Given a compact or wide window with increased text scale
When a primary destination is displayed
Then essential content and navigation remain accessible without clipping
```

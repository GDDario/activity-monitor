# Application Foundation

## Purpose

Provide a consistent application foundation so that users can access the
Activity Monitor interface with predictable navigation, localization, and
presentation feedback.

## Users and use cases

- As an Activity Monitor user, I want the app to open at the daily overview so
  that I can begin from the current activity context.
- As an Activity Monitor user, I want the app to use a supported locale so that
  standard interface components are presented consistently.
- As an Activity Monitor user, I want transient feedback to be presented in a
  consistent accessible location so that I understand the result of an action.

## Requirements

1. `REQ-FOUND-001`: The application MUST open at the daily overview.
2. `REQ-FOUND-002`: The application MUST provide navigation infrastructure
   without changing the daily overview's visible content.
3. `REQ-FOUND-003`: The application MUST support English locale resources.
   `[ASSUMPTION: English is the only product locale currently required.]`
4. `REQ-FOUND-004`: The application MUST provide a single application-wide
   presentation-feedback host for transient messages.
5. `REQ-FOUND-005`: Application-wide dependencies MUST be composed at the
   application boundary and remain replaceable in tests.

## Business rules

- Navigation destination selection is presentation state; it MUST NOT contain
  domain behavior.
- User-facing messages MUST be presentation-safe and MUST NOT expose technical
  or sensitive error details.
- Newly generated persistent entity identifiers MUST be UUID version 7.

## Edge cases

- If an unknown in-app location is requested, the application MUST display a
  presentation-safe fallback rather than crash.
- If the device locale is unsupported, the application MUST use a supported
  locale. `[ASSUMPTION: Flutter's standard locale fallback is sufficient.]

## Acceptance criteria

```text
Given the application has started
When no location is requested
Then the daily overview is displayed

Given the daily overview is displayed
When the application is built
Then it has an application-wide navigation configuration, localization
delegates, and presentation-feedback host

Given an unsupported in-app location
When the location is resolved
Then a presentation-safe fallback is shown without an uncaught error
```

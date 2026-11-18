# SECTION 1: SPEC

> Delivery update (2026-11-18): the user subsequently authorized committing
> and pushing the validated features on their issue branches. Earlier local-only
> restrictions below describe the implementation phase. Profile is delivered on
> `feature/9-profile-screen`, based on `feature/8-people-screen`.
> Issue/project/PR mutations remain outside this authorization.

## One-line purpose

Let users identify their local profile and choose a lasting appearance and
language for their Activity Monitor experience.

## Status and sources

Approved by the user's 'go ahead' response to the specification and
PRO01–PRO08 review request for issue #9, Profile screen. The user supplied its Todo status
and empty issue body in the project export; no GitHub access or mutation is
needed for this work. The completed local People changes MUST be preserved,
along with the user's existing dependency-lock changes. No commits, pushes,
issue changes or pull requests are authorized.

Sources:

- [Constitution](../../project/constitution.md) and
  [design reference](../../project/design-reference.md).
- [Application foundation](../FEATURE%201%20-%20application%20foundation/spec.md):
  Profile destination, shared avatar navigation, supported languages, and the
  existing rule that a profile name is required for setup and app usage.
- The user-supplied foundation issue #1: avatar/name settings, dark/light/system
  appearance and initial pt-BR/en-US language preferences.
- [Home](../FEATURE%204%20-%20home%20screen/spec.md): truthful local greetings
  and identity, with a neutral avatar until real profile information exists.
- [Tasks](../FEATURE%203%20-%20tasks/spec.md) and
  [People](../FEATURE%205%20-%20people%20screen/spec.md): saved activity data,
  participant identities, shared mutation feedback and existing local integrity.

No Profile-specific Stitch HTML or image exists in the supplied local export.
The canonical design reference and established application components govern
this screen. A Profile-specific visual comparison MUST NOT be claimed without
an actual reference. Requirements below distinguish supplied behavior from
proposed choices needing review.

## Users and use cases

- As a new user, I want to name my local profile so that the app can identify
  me without requiring an online account.
- As a user, I want to change my name and avatar so that my profile remains
  recognizable throughout the application.
- As a user, I want to select light, dark or system appearance so that the app
  remains comfortable and readable in my environment.
- As a user, I want to choose Portuguese or English so that application controls
  and dates use my preferred language.
- As a user, I want settings to survive reopening without changing my saved
  tasks, companions or calendar state.

## Requirements

1. **REQ-PRO-001 — Entry point:** Profile MUST replace the existing placeholder
   within the current application navigation. Selecting the shared profile
   avatar MUST still open Profile. The screen MUST present profile identity,
   appearance and language as clearly separated, accessible groups using the
   established calm editorial design.
2. **REQ-PRO-002 — Local setup:** A usable saved local profile MUST have a name.
   Setup MUST work offline and MUST NOT require authentication or an email.
   **PRO01 (approved):** this delivery enforces the foundation's deferred setup
   rule: if no named profile exists, show first-time Profile setup before the
   other application screens become available. Existing task/People data MUST
   remain intact. A failed profile read shows Retry rather than falsely treating
   the user as new. After successful setup, open the originally requested valid
   destination, defaulting to Today. Setup may change appearance/language before
   saving but cannot be dismissed into the app without a saved name.
3. **REQ-PRO-003 — Name:** Users MUST be able to enter and update a required
   display name. Surrounding whitespace MUST be removed. Empty or invalid input
   MUST produce a localized field error without saving other draft changes.
   **PRO02 (approved):** accept 1–100 Unicode scalar characters after trimming;
   preserve internal spacing, punctuation, capitalization and non-Latin names.
   The local profile name need not be unique and MUST NOT rename a companion
   or create a person in the People directory.
4. **REQ-PRO-004 — Avatar:** Users MUST be able to change the local profile
   avatar, preview the chosen image, cancel image selection, and remove a saved
   photo to return to an initials avatar. The application MUST retain a usable
   fallback when a saved image becomes unavailable.
   **PRO03 (approved):** provide local photo selection plus an initials fallback,
   without camera capture, remote URLs, stock portraits or generated identities.
   Accept supported decodable JPEG/PNG images up to 5 MiB; reject corrupt,
   unsupported or oversized input with a localized message. A selected image is
   owned locally after save, so removing its source file does not break the saved
   avatar. If the platform cannot provide photo selection, state that clearly
   and retain the fully usable initials fallback.
5. **REQ-PRO-005 — Shared identity:** After a successful save, shared headers
   MUST use the saved photo or name-derived initials and an accessible profile
   label. Home MUST use real saved identity without inventing presence,
   achievements or account status.
   **PRO04 (approved):** Home appends the full display name to its existing
   time-based greeting; other screens keep their contextual titles/phrases.
   Initials use the first visible character of the first and last nonempty name
   parts, or the first character for a single-part name, without splitting a
   visible character sequence. Long names wrap without hiding header actions.
6. **REQ-PRO-006 — Appearance:** Users MUST be able to select Light, Dark or
   Follow system. The saved choice MUST apply throughout the application,
   including navigation, sheets, task cards, selected/unselected filters,
   editors, loading/error/empty states and Undo feedback. Dark appearance MUST
   provide readable text, controls and focus states; merely changing the outer
   background while retaining unreadable light surfaces does not satisfy this
   requirement. Selection MUST NOT depend on color alone.
   **PRO05 (approved):** Follow system is the initial preference. A saved system
   preference responds to device appearance changes while the app runs; explicit
   Light or Dark ignores those changes. Existing layout and behavior remain.
7. **REQ-PRO-007 — Language:** Users MUST be able to choose English (United
   States), Portuguese (Brazil) or Follow device. A saved choice MUST update
   application controls, validation, date/time formatting, plurals, semantics,
   existing screens and subsequently opened dialogs without restarting.
   User-authored names, notes, roles, tags and task titles MUST NOT be translated
   or rewritten. Language selection MUST remain identifiable in either language.
   **PRO06 (approved):** Follow device is the initial preference. Resolve English
   device variants to en-US and Portuguese variants to pt-BR; unsupported device
   languages fall back to en-US, following the foundation. Display explicit
   choices as English (United States) and Português (Brasil) in their own
   languages so users can recover from an accidental choice.
8. **REQ-PRO-008 — Save and cancel:** Users MUST receive clear save success,
   progress and failure feedback. A failed save MUST retain editable draft
   values and leave the previously saved profile usable. Repeated activation
   during saving MUST NOT create duplicate profiles or competing saves.
   **PRO07 (approved):** name, avatar, appearance and language form one draft
   with explicit Save. Preview the avatar in Profile; appearance and language
   become application-wide only after a successful save. Cancel restores saved
   values. Dismissing a dirty editor requires Discard/Keep editing, while first
   setup remains required. Saving and committing the settings is one operation
   from the user's perspective; a failed photo import must not partially save
   the remaining settings.
9. **REQ-PRO-009 — Durability and conflicts:** Saved identity/preferences MUST
   survive application termination and reopening. Existing activity, companion,
   recurrence and mutation state MUST remain unchanged by profile writes.
   Conflicting saves MUST fail safely instead of replacing newer saved data.
   An unsuccessful upgrade MUST NOT reset the user's data or fabricate a profile.
10. **REQ-PRO-010 — Runtime continuity:** Applying preferences MUST preserve the
    current destination, selected Calendar date/mode, valid Home/People filters
    and pending Undo state. It MUST NOT duplicate task mutations or recreate
    initial sample data. A language or theme rebuild MUST NOT discard an open
    task draft. First-time setup redirects are the explicit exception described
    by REQ-PRO-002.
11. **REQ-PRO-011 — Availability and recovery:** Loading profile settings,
    first-time setup and storage unavailable MUST be distinct states. Retry MUST
    retain valid draft input where applicable. If a saved avatar cannot be read,
    use name-derived initials without pretending the saved name/settings were
    lost. Failures MUST NOT reveal filesystem paths or private profile content.
12. **REQ-PRO-012 — Accessibility and responsive layout:** All controls MUST
    have accessible names, selected-state semantics where applicable, visible
    keyboard focus and adequate touch targets. Both supported languages, compact
    and wide screens, and 320 logical pixels with doubled text MUST keep essential
    content/actions reachable. The software keyboard MUST NOT prevent reaching
    Save/Cancel. Avatar and appearance meanings MUST NOT rely on color alone.
13. **REQ-PRO-013 — Delivery boundary:** This feature MUST NOT introduce online
    accounts, sign-in/out, profile sharing, contact synchronization, device data
    deletion/reset, notification delivery, subscription controls or fabricated
    statistics. Notification behavior remains issue #15. Profile data MUST NOT
    be sent to external services by this feature.

## Business rules

- There is one current local profile for this installation.
  **PRO08 (approved):** multiple profiles and profile switching are deferred;
  existing participants remain independent companion identities.
- Name validity belongs to profile identity. Profile appearance/language choices
  are stable values independent of translated labels; translated display text
  MUST NOT be used as saved preference identity.
- A profile photo is optional. Removing or failing to read a photo MUST NOT
  remove the profile or require a new setup. Canceling photo selection MUST
  preserve the current draft photo and other unsaved input.
- A name-derived avatar MUST use real saved/draft identity; the initial neutral
  avatar before setup MUST NOT imply a named or authenticated user exists.
- Saved settings are the source of truth for application preferences. Unsaved
  input MUST NOT become durable or change unrelated screens' saved state.
- Appearance changes presentation only. Language changes presentation and
  formatting only. Neither changes effective dates, time zones, completion,
  participant membership, identity or scheduled reminders.
- An unavailable profile store is not evidence that no profile exists. Recovery
  MUST preserve existing data rather than bypass the failure with a new profile.

## Edge cases

| Situation | Expected behavior |
| --- | --- |
| Existing installation has tasks/people but no profile | Require named setup under PRO01 without deleting or rewriting existing data. |
| New profile read fails | Unavailable/Retry; no writeable replacement profile based on an assumed empty state. |
| Empty/whitespace-only or overlong name | Localized field validation; no partial settings save. |
| Single-part, multi-part, emoji or combining-character name | Readable initials without broken character sequences; preserve the full name. |
| Picker canceled, corrupt/oversized image or unavailable picker | Preserve prior draft/avatar and show appropriate guidance. |
| Original photo source is removed after save | The owned saved avatar remains available. |
| Saved avatar itself becomes unreadable | Use saved-name initials while retaining the remaining profile/preferences. |
| Device language/theme changes | Only saved Follow device/system preferences follow those changes. |
| Explicit language or appearance is selected | It remains authoritative across device preference changes and app restart. |
| Preference save fails or conflicts | Prior settings remain active, draft retained, and retry/reload feedback is shown. |
| Settings apply while another feature retains state | Keep destination, Calendar selection, scopes, task draft and Undo intact. |
| Enlarged text and keyboard on compact screens | Scroll/reflow; all essential controls remain reachable and focus-visible. |

## Acceptance criteria

1. **AC-PRO-001:** Given no saved named profile, when the app starts online or
   offline, then setup requires a valid name before opening another destination.
2. **AC-PRO-002:** Given preexisting saved tasks and companions without a profile,
   when setup succeeds, then those records remain unchanged and the requested
   valid destination opens.
3. **AC-PRO-003:** Given a valid profile draft, when Save succeeds and storage
   reopens, then the same name, avatar and preference choices are restored.
4. **AC-PRO-004:** Given an invalid name, when Save is activated, then a localized
   field error appears and none of the draft settings are persisted.
5. **AC-PRO-005:** Given a changed draft, when the user discards it or keeps
   editing after a dismissal prompt, then saved values remain unchanged and the
   draft follows the selected action.
6. **AC-PRO-006:** Given photo selection is available, when a valid image is
   chosen and saved, then headers use that owned image even after the source is
   removed; removing the avatar restores saved-name initials.
7. **AC-PRO-007:** Given a canceled or invalid photo choice, when selection
   finishes, then the previous avatar/draft remains and any invalid-input message
   is localized; no other field is partially saved.
8. **AC-PRO-008:** Given single-part, multi-part and composed-character names,
   when the fallback avatar renders, then its initials follow PRO04 without
   broken visible characters and Home uses the full saved display name.
9. **AC-PRO-009:** Given saved explicit Light or Dark, when the device appearance
   changes or the app restarts, then the chosen appearance remains authoritative
   and all existing destinations and transient controls remain readable.
10. **AC-PRO-010:** Given saved Follow system, when device appearance changes,
    then the app follows it without restarting or losing feature state.
11. **AC-PRO-011:** Given an explicit saved language, when it changes successfully,
    then controls, semantics and date formatting throughout the app use that
    language without rewriting user content or requiring restart.
12. **AC-PRO-012:** Given Follow device, when the device language is Portuguese,
    English or unsupported, then the resolved language is respectively pt-BR,
    en-US or en-US.
13. **AC-PRO-013:** Given unsaved appearance/language changes or a failed save,
    when another destination is viewed or storage is reopened, then only the
    previously saved preferences remain active.
14. **AC-PRO-014:** Given unavailable storage, conflicting writes or an unreadable
    saved avatar, when the failure is encountered, then the specified recovery
    state preserves existing data and never silently resets the profile.
15. **AC-PRO-015:** Given a selected Calendar date, retained scopes or pending
    Undo, when saved preferences apply, then that feature state remains intact
    without duplicate mutations or initial-data seeding.
16. **AC-PRO-016:** Given both languages and appearances, keyboard navigation,
    compact/wide layouts and 320px doubled-text rendering with the software
    keyboard, when setup and profile editing are exercised, then all essential
    content/actions are readable, accessibly named, focus-visible and reachable.

## Approved scope choices

- **PRO01 (high):** enforce first-time named setup now, preserving old data and
  returning to the originally requested destination.
- **PRO03 (high):** owned local JPEG/PNG photo import up to 5 MiB plus initials;
  no camera/remote photo flow, with clear fallback on unsupported platforms.
- **PRO07 (high):** one explicit Save for identity and preferences; global theme
  and language apply after success, with no partial save on image failure.
- **PRO08 (medium):** one local profile, separate from People identities.
- **PRO02 (medium):** trimmed 1–100-character name, Unicode-aware validation.
- **PRO04 (medium):** full name in Home greeting and visible-character-safe
  first/last-part initials in shared headers.
- **PRO05 (medium):** initial appearance follows system, with functional dark
  styling across all existing screens.
- **PRO06 (medium):** initial language follows device, with explicit en-US/pt-BR
  and supported-language resolution rules above.

PRO01–PRO08 and plan choices PRP01–PRP03 were approved. Implementation and local
validation are complete; acceptance evidence and platform limits are recorded in
[tasks.md](tasks.md). GitHub issue/project status remains unchanged.

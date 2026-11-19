# SECTION 3: TASKS

Read spec.md/plan.md, constitution, architecture, conventions, design reference,
SQLite ADR and app/AGENTS.md. Follow failing test → minimum passing implementation
→ refactor. Preserve existing data and user lockfile edits. The user delegated
routine choices and explicitly removed document approval pauses.

## Task 1: Reminder projection

**Build:** effective-date lead-time projection with eligibility, DST and bounded queue.
**Files:** domain models/use case, domain tests. **Dependencies:** none.
**Acceptance:** AC-NOT-001–003, 010.
- [x] Write and observe failing eligibility, midnight, recurrence/exception and cap tests.
- [x] Implement pure deterministic projection and verify boundary tests.
- [x] Refactor and verify existing scheduling tests.

## Task 2: Durable opt-in and native identities

**Build:** migration 0007, atomic allocation and persisted opt-in.
**Files:** migration/database/repository and SQLite tests. **Dependencies:** Task 1.
**Acceptance:** AC-NOT-006, 013.
- [x] Test v6 preservation, singleton constraints, stable IDs, reopening and rollback first.
- [x] Implement isolated database service and verify tests pass.
- [x] Verify task/profile/People migration regressions.

## Task 3: Native notification boundary

**Build:** no-prompt initialization, permissions/timing capabilities and scheduling.
**Files:** native service/repository, manifest/Gradle/iOS, dependencies. **Dependencies:** Task 2.
**Acceptance:** AC-NOT-005–009, 014.
- [x] Test permission, unsupported, idempotence, cancellation and partial failure retry first.
- [x] Implement native adapter, stable-ID reconciliation and native configuration.
- [x] Audit dependency changes and preserve original user records.

## Task 4: Lifecycle reconciliation and taps

**Build:** committed-state orchestration and safe Calendar navigation.
**Files:** use case, ViewModel, dependencies/root and tests. **Dependencies:** Task 3.
**Acceptance:** AC-NOT-004, 007–011.
- [x] Test refresh serialization/coalescing, failed writes, resume and valid/invalid taps first.
- [x] Implement task/profile listeners, minute refresh and guarded cold-launch navigation.
- [x] Verify no background Dart timer is required for native delivery.

## Task 5: Accessible localized controls

**Build:** notification panel and truthful task reminder labels.
**Files:** modal/localizations/bell/editor/card and widget tests. **Dependencies:** Task 4.
**Acceptance:** AC-NOT-005–006, 010, 012.
- [x] Test opt-in, denied/error/retry, EN/PT, both themes and compact doubled text first.
- [x] Implement reachable controls, actual confirmed queue and timing/horizon guidance.
- [x] Compare fresh renders with applicable design references and inspect keyboard state.

## Task 6: Final validation and delivery

**Build:** acceptance evidence and orderly issue-branch delivery. **Dependencies:** Task 5.
**Acceptance:** all AC-NOT criteria evidenced; platform limits explicit.
- [x] Run format, analysis, full tests and Android debug APK; inspect logs.
- [x] Verify native permission and real background delivery without resetting device data.
- [x] Review fresh screenshots and audit dependencies, docs and diff.
- [x] Prepare validated source on feature/15-notifications and a PR description;
  exclude generated build output from the feature changes.

The user explicitly authorized committing all source changes, pushing, opening a
PR and merging into main on 2026-11-19. The original `test_api` and `vector_math`
lockfile updates are retained in a separate maintenance commit. GitHub PR history
is the delivery record; local evidence remains in the validation directory below.

## Review checkpoint

Confirm native delivery, queue repair after mutations, permission honesty, runtime
continuity and accessible controls before declaring the issue complete.

## Assumptions to review

The user explicitly removed approval pauses. These choices were made under that
instruction; no separate individual review is claimed.

1. Assumption: NOT01 — Android/iOS native support, other platforms explicitly unsupported.
   Assumption answer: Delegated implementation choice; iOS remains unverified on this Linux host.
2. Assumption: NOT02 — separate persisted opt-in, initially off.
   Assumption answer: Delegated implementation choice; existing per-task defaults remain Off.
3. Assumption: NOT03 — earliest 64 reminders firing in the next 30 days.
   Assumption answer: Delegated implementation choice; bound and reopening guidance are visible.
4. Assumption: NOT04 — Android precise timing when authorized, approximate otherwise.
   Assumption answer: Delegated implementation choice; optional timing permission and status provided.
5. Assumption: NOT05 — stable native identity and explicit partial-failure retry.
   Assumption answer: Delegated implementation choice; reconciliation tests verify repair without duplicates.
6. Assumption: NOT06 — local title-bearing notifications with private Android visibility.
   Assumption answer: Delegated implementation choice; diagnostics omit authored content and payloads.
7. Assumption: NOT07 — current device time zone; skip gaps and resolve overlaps once.
   Assumption answer: Delegated implementation choice; real zone DST and resume tests pass.

## Validation evidence

Feature implementation is complete locally on `feature/15-notifications`.
Fresh run: `.scratches/notifications-validation/20261119-145600/`, generated by
`bash .scratches/recheck-notifications.sh`. Formatting, analysis, all **476 tests**,
capture fixtures, Android debug APK and dependency audit pass. Analysis retains
75 infos: 72 SDK Material deprecations plus the three preexisting Home style
findings; no errors/warnings. A final unused test import was removed and analysis
rerun. After adding the release icon keep rule, the APK build was rerun into the
same evidence directory. The existing Kotlin migration warning remains nonfatal.

**164 reviewed captures** cover both languages/appearances at compact 390×844,
reference 585×1500, wide 1200×900 and 320×800 doubled text. States include Off,
denied, unsupported, unavailable, empty, queued, approximate and scrolled actions.
Final captures are byte-identical to the reviewed contact-sheet inputs. The
heading width regression was observed Red before reflowing the close control;
the enlarged heading now stays readable. Keyboard Tab/Space, named/minimum-size
targets, contrast and action reachability pass widget checks.

There is no notification-specific Stitch export. The panel follows the canonical
editorial design and shared theme/components. The actual native Home shell and
bell entry retain the supplied Today reference hierarchy; the modal is reviewed
against the canonical design rather than an invented Stitch match.

Native Android evidence was captured on emulator-5554. A temporary in-memory probe
used the production native adapter without creating a profile or task in the
user database. Explicit enable opened the Android permission dialog. The system
registered a scheduled alarm and delivered “Notification delivery check” while
the app was backgrounded: `native-alarms.txt`, `native-delivered.txt` and
`native-background-delivery.png`. The approximate timing path was exercised;
precise timing is covered at the native method-channel boundary. Reboot
rescheduling is configured through the plugin receivers but not independently
reboot-tested. The device's original denied notification permission and default
exact-alarm access were restored. The normal app was restored, schema 7 and saved
profile availability checked, and the real bell panel verified with opt-in Off.
No device data reset occurred. iOS configuration is present but cannot be built
or verified on this Linux host. Other platforms intentionally report unsupported.

Dependency audit: all existing package records, including the user's `test_api`
and `vector_math` records/hashes, are unchanged. Ten packages were added for local
notifications, time-zone discovery and their dependencies. Version 22.0.1 follows
the available Flutter/Android SDK rather than requiring compile SDK 37. The
Android icon is retained explicitly for resource shrinking; release-mode delivery
and iOS native delivery are not claimed as verified by the debug APK check.

## Acceptance mapping

| Criterion | Evidence |
| --- | --- |
| AC-NOT-001–003 | Projection tests cover eligibility, lead times, effective/moved dates, midnight, exact rolling-horizon boundary and real DST gaps/overlaps. |
| AC-NOT-004 | Real SQLite workflow verifies completion, Undo, postpone, deletion and rejection of an invalid write without speculative scheduling. |
| AC-NOT-005–006 | Native method-channel and repository tests verify no startup prompts, explicit permission, persisted opt-in and disable/cancel; real Android permission dialog reviewed. |
| AC-NOT-007 | Stable-ID/reopen/idempotence tests and serialized/coalesced ViewModel refreshes prevent duplicate scheduling. |
| AC-NOT-008 | Storage/migration failure and partial native failure tests preserve data, show unavailable and repair only missing entries on retry. |
| AC-NOT-009 | Repository tests update locale/zone signatures and repair pending content after reopening; lifecycle regression verifies foreground-only timer and refresh on resume. |
| AC-NOT-010 | Real daily recurrence fills 64 reminders and replenishes the next entry after completion; the visible horizon guidance matches the projection. |
| AC-NOT-011 | Invalid payload parsing, current-occurrence lookup, moved/deleted tap workflow and native cold-launch payload tests verify safe Calendar selection. Required setup precedes starting notification composition. |
| AC-NOT-012 | EN/PT localization, four compact doubled-text accessibility cases, Tab/Space keyboard test, heading regression and all 164 captures. |
| AC-NOT-013 | v6 upgrade, constraints, rollback, stable IDs/reopen and existing task/People/Profile migration suites. |
| AC-NOT-014 | Real Android system alarm and background-delivered notification captured through the production native adapter. |

# SECTION 3: TASKS

> Delivery update (2026-11-18): the user subsequently authorized committing
> and pushing the validated features on their issue branches. Earlier local-only
> restrictions below describe the implementation phase. Profile is delivered on
> `feature/9-profile-screen`, based on `feature/8-people-screen`.
> Issue/project/PR mutations remain outside this authorization.

Read spec.md, plan.md, project constitution, architecture, conventions, design reference, SQLite ADR and app/AGENTS.md. Follow failing test → minimum implementation → refactor. All work stays local; no commits, pushes or GitHub changes. Preserve the existing People work and user lockfile records.

## Task 1: Profile invariants and first-run state

**What to build:** ProfileName scalar bounds, visible-character initials, enum identity and immutable image bytes; distinguish absent from unavailable.
**Files likely affected:** domain/models/local_profile.dart; domain/value_objects/profile_name.dart; profile domain tests.
**Dependencies:** none
**Acceptance criteria:** ProfileName scalar bounds, visible-character initials, enum identity and immutable image bytes; distinguish absent from unavailable.

- [x] Write focused acceptance tests and observe the expected failures.
- [x] Implement the minimum passing behavior without duplicating domain validation.
- [x] Refactor and verify relevant existing tests still pass.

## Task 2: Transactional profile persistence

**What to build:** Migration 0006, fresh/v5 upgrades, singleton/revision constraints, atomic owned image/settings saving and durable reads.
**Files likely affected:** database/migrations/migration_0006_create_local_profile.dart; profile database/repository; migration/repository tests.
**Dependencies:** Task 1
**Acceptance criteria:** Migration 0006, fresh/v5 upgrades, singleton/revision constraints, atomic owned image/settings saving and durable reads.

- [x] Write focused acceptance tests and observe the expected failures.
- [x] Implement the minimum passing behavior without duplicating domain validation.
- [x] Refactor and verify relevant existing tests still pass.

## Task 3: Local avatar selection

**What to build:** Native photo picker adapter, format/size checks, bounded normalization, cancellation and error results; preserve lockfile edits.
**Files likely affected:** avatar repository/services; pubspec; native plugin registrants; avatar tests.
**Dependencies:** Task 2
**Acceptance criteria:** Native photo picker adapter, format/size checks, bounded normalization, cancellation and error results; preserve lockfile edits.

- [x] Write focused acceptance tests and observe the expected failures.
- [x] Implement the minimum passing behavior without duplicating domain validation.
- [x] Refactor and verify relevant existing tests still pass.

## Task 4: Session, setup gate and editor state

**What to build:** Retained draft, duplicate-submit and stale guards; required setup, safe return destination and explicit save/cancel/discard.
**Files likely affected:** profile ViewModels/dependencies; app router; session/editor/routing tests.
**Dependencies:** Task 3
**Acceptance criteria:** Retained draft, duplicate-submit and stale guards; required setup, safe return destination and explicit save/cancel/discard.

- [x] Write focused acceptance tests and observe the expected failures.
- [x] Implement the minimum passing behavior without duplicating domain validation.
- [x] Refactor and verify relevant existing tests still pass.

## Task 5: Profile screen and shared identity

**What to build:** Localized responsive setup/edit form, real image/initials across headers and full saved-name Home greeting.
**Files likely affected:** Profile views/widgets/localizations; shared avatar; Home header; widget tests.
**Dependencies:** Task 4
**Acceptance criteria:** Localized responsive setup/edit form, real image/initials across headers and full saved-name Home greeting.

- [x] Write focused acceptance tests and observe the expected failures.
- [x] Implement the minimum passing behavior without duplicating domain validation.
- [x] Refactor and verify relevant existing tests still pass.

## Task 6: App-wide appearance and language

**What to build:** Stable router/providers; semantic light/dark palette across existing screens and locale resolution; preserve Calendar, scopes, drafts and Undo.
**Files likely affected:** ActivityTheme/ActivityPalette; root app; shared/Home/Calendar/People/Tasks presentation; app integration tests.
**Dependencies:** Task 5
**Acceptance criteria:** Stable router/providers; semantic light/dark palette across existing screens and locale resolution; preserve Calendar, scopes, drafts and Undo.

- [x] Write focused acceptance tests and observe the expected failures.
- [x] Implement the minimum passing behavior without duplicating domain validation.
- [x] Refactor and verify relevant existing tests still pass.

## Task 7: Acceptance and visual verification

**What to build:** Full regression suite, native startup/keyboard/photo boundary, light/dark/locale screenshots, Android build and dependency preservation audit.
**Files likely affected:** test suites and .scratches/profile-validation artifacts.
**Dependencies:** Task 6
**Acceptance criteria:** Full regression suite, native startup/keyboard/photo boundary, light/dark/locale screenshots, Android build and dependency preservation audit.

- [x] Write focused acceptance tests and observe the expected failures.
- [x] Implement the minimum passing behavior without duplicating domain validation.
- [x] Refactor and verify relevant existing tests still pass.

## Verification checklist

- [x] Enforce a valid name during first setup without changing existing task/People data.
- [x] Verify unavailable profile storage cannot become a writable replacement profile.
- [x] Verify singleton creation conflict, stale save rejection and atomic settings/photo rollback in real SQLite.
- [x] Verify avatar cancellation, unsupported/corrupt/oversized input, normalization and owned-source independence.
- [x] Verify successful setup returns to a safe originally requested destination and Back cannot bypass it.
- [x] Verify explicit/system theme and language behavior, profile identity and runtime updates.
- [x] Verify Calendar selection, scopes, open task drafts and pending Undo survive preference changes.
- [x] Verify name/category/task user content remains untranslated and unchanged.
- [x] Verify EN/PT, light/dark, compact/wide/320px doubled-text, keyboard and focus/target/contrast states.
- [x] Compare existing light screens against actual Stitch references; report that no Profile/dark export exists.
- [x] Pass format, analysis, full tests and Android debug build; inspect all final logs.
- [x] Audit manifest/lock diff, preserve user records, synchronize acceptance evidence and leave all work local.

## Review checkpoint

Verify setup cannot be bypassed, settings save atomically, existing feature state survives root preference changes, and every existing destination remains readable in both appearances before declaring complete.

## Assumptions to review

- Assumption: PRO01, as described in spec.md or plan.md.
  Assumption answer: Approved in the user response to the corresponding document review.
- Assumption: PRO02, as described in spec.md or plan.md.
  Assumption answer: Approved in the user response to the corresponding document review.
- Assumption: PRO03, as described in spec.md or plan.md.
  Assumption answer: Approved in the user response to the corresponding document review.
- Assumption: PRO04, as described in spec.md or plan.md.
  Assumption answer: Approved in the user response to the corresponding document review.
- Assumption: PRO05, as described in spec.md or plan.md.
  Assumption answer: Approved in the user response to the corresponding document review.
- Assumption: PRO06, as described in spec.md or plan.md.
  Assumption answer: Approved in the user response to the corresponding document review.
- Assumption: PRO07, as described in spec.md or plan.md.
  Assumption answer: Approved in the user response to the corresponding document review.
- Assumption: PRO08, as described in spec.md or plan.md.
  Assumption answer: Approved in the user response to the corresponding document review.
- Assumption: PRP01, as described in spec.md or plan.md.
  Assumption answer: Approved in the user response to the corresponding document review.
- Assumption: PRP02, as described in spec.md or plan.md.
  Assumption answer: Approved in the user response to the corresponding document review.
- Assumption: PRP03, as described in spec.md or plan.md.
  Assumption answer: Approved in the user response to the corresponding document review.


## Completion and validation evidence

Completed locally on 2026-11-18. No commit, push, issue/project update or PR was
created. Existing People work and the user's original lockfile records remain.

Final evidence: `.scratches/profile-validation/20261118-180322/`, generated by
`bash .scratches/recheck-profile.sh`. All six checks in `results.txt` passed:
formatting, analysis, 446 tests, capture fixtures, Android debug APK and dependency
audit. A final braces-only cleanup in the accessibility test was followed by
`accessibility-final.log` (all four cases passed) and `analyze-final.log`.
Analysis has no errors or warnings: 72 informational findings remain (69 SDK
Material deprecations and three preexisting style findings in Home domain/state
files). The existing Kotlin migration warning does not prevent the APK build.

Reviewed 276 captures across en-US/pt-BR, light/dark and compact (390×844),
reference (585×1500), wide (1200×900) and 320×800 doubled-text layouts. Evidence
includes setup, identity/photo, edit, invalid input, loading/unavailable, Home,
Calendar, People, task creation, Undo, scrolled content and keyboard actions.
Contact sheets are in `contact/`; full images are in `captures/`. Capture-only
photo precaching was corrected and all 16 capture scenarios rerun successfully
without changing production code. Test-generated unavailable-state logs are
intentional failure fixtures.

Existing light screens were compared with the supplied Stitch HTML/images for
Today, Calendar, People and task creation. Profile and dark mode have no supplied
Stitch exports; these were reviewed against the canonical design reference,
semantic contrast and existing component hierarchy. No pixel match to a missing
reference is claimed. Essential enlarged-text actions remain reachable through
scrolling; long Calendar month headings retain their existing wrapping behavior.

Native Android verification on emulator-5554 confirmed migration/startup into
required setup, native photo-picker opening and cancellation, and Save remaining
reachable above the actual software keyboard after scrolling. See
`native-photo-picker.png`, `native-keyboard-actions.png` and `native-run.log`.
No sample profile was saved or device data reset. The keyboard was dismissed and
the Flutter runner detached. Other native platforms were not run; unsupported
picker behavior is covered through the service boundary and initials fallback.

The dependency audit compares against the pre-change lockfile snapshot. Existing
`test_api` 0.7.14 and `vector_math` 2.4.4 records, including hashes, are unchanged.
Ten file-selector-related packages were added and `characters` became a direct
dependency without changing its locked version. No other prior package record
changed. Native plugin registration was regenerated by Flutter.

## Acceptance evidence

| Criterion | Verified evidence |
| --- | --- |
| AC-PRO-001 | Routing tests: required named setup, Back/deep-link guard, offline local storage. |
| AC-PRO-002 | Migration tests preserve v5 task/People data; routing returns to the requested Calendar destination after setup. |
| AC-PRO-003 | Real SQLite repository close/reopen restores name, owned avatar and enum preferences. |
| AC-PRO-004 | Domain/form tests reject blank/overlong names, focus the localized error and avoid partial persistence. |
| AC-PRO-005 | Runtime/editor tests exercise Keep editing, Discard, retained drafts and explicit Save. |
| AC-PRO-006 | Repository tests delete the source image after save and reopen owned bytes; avatar/state tests cover removal and shared rendering. |
| AC-PRO-007 | Avatar tests cover cancellation, corrupt/unsupported/oversized input, real JPEG/PNG normalization and reported/actual byte bounds. |
| AC-PRO-008 | Domain tests cover grapheme-safe initials and scalar name limits; runtime/capture checks show full saved-name Home greetings. |
| AC-PRO-009 | Persistence/runtime tests retain explicit appearance; semantic role, dark card/ring/priority regressions and all dark captures verify readable states. |
| AC-PRO-010 | Runtime preference tests follow device brightness while preserving a stable router and retained feature state. |
| AC-PRO-011 | Runtime tests update controls and success feedback to the committed locale; EN/PT captures retain original names, roles, tags and task content. |
| AC-PRO-012 | Domain/runtime tests resolve Portuguese and English variants and unsupported-device fallback; explicit locale remains authoritative. |
| AC-PRO-013 | Editor and SQLite rollback tests retain prior committed settings across canceled/failed saves; picker failures do not partially save. |
| AC-PRO-014 | SQLite singleton/stale-write/rollback tests, unavailable-store routing, stale-read guards and corrupt-avatar fallback preserve valid state. |
| AC-PRO-015 | Integration test retains Calendar date/mode, Home/People scopes, an open task draft and pending Undo across preference changes. |
| AC-PRO-016 | Four locale/appearance accessibility cases verify named targets, target sizes and contrast at 320px/doubled text; form focus, keyboard fixtures, all captures and native IME check verify reachable actions. |

Migration 0006 adds only the singleton local profile, with no seeded identity.
Profile/settings/image updates are atomic and revision guarded. Calendar's
provider now retains selection across destination changes, as required by
REQ-PRO-010 and the corresponding updated Calendar specification. Compact task
priority controls wrap into labeled choices at enlarged text sizes. No additional
feature behavior or notification delivery was introduced.


## Branch separation verification

Profile is stacked on the independently verified People commit. Production and
test sources match the final validated snapshot byte for byte; only delivery
documentation changed. Fresh branch checks are recorded in
`.scratches/branch-organization/profile-{format,analyze,tests}.log`. The feature
commit includes new dependency entries while retaining the original branch's
`test_api` and `vector_math` records; the user's edits to those two records stay
in the working tree. Build artifacts and temporary evidence are excluded.

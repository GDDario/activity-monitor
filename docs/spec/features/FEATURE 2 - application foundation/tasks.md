# Application Foundation Tasks

## Task 1: Document the application foundation

**What to build:** Establish this specification before application changes.
**Files likely affected:** `docs/spec/features/FEATURE 1 - application foundation/`
**Acceptance criteria:**
1. The specification defines navigation, locale, feedback, dependency-composition, and fallback behavior.
2. The plan preserves the View → ViewModel → Use Case → Repository → Service boundaries.
**Dependencies:** none

## Task 2: Compose application infrastructure

**What to build:** Starting with failing widget and factory tests, compose the router, localization, feedback host, dependency scope, HTTP client factory, and UUID v7 factory. Keep generated-model tooling unused until a feature owns a model or DTO.
**Files likely affected:** `app/lib/app/`, `app/lib/data/services/`, `app/test/`
**Acceptance criteria:**
1. The app opens at the dashboard through the router and preserves its current visible content.
2. The root provides English localization delegates and a single feedback host.
3. The HTTP client and UUID v7 generator are obtainable through composition without network I/O.
4. `dart format .`, `flutter analyze`, and `flutter test` pass.
**Dependencies:** Task 1

## Review checkpoint

Verify that the dashboard appearance remains aligned with the design reference
and that no Views access a service directly.

## Assumptions to review

1. English is the only required product locale — Impact: MEDIUM. Correct this
   before adding translated application strings.
2. Flutter's standard locale fallback is sufficient — Impact: LOW. Correct this
   if a custom unsupported-locale experience is required.
3. Riverpod state-owning ViewModels will be introduced only with a feature that
   needs them — Impact: MEDIUM. Correct this if a shared application state is
   already known.
4. A 15-second HTTP timeout is appropriate until a remote API contract exists —
   Impact: MEDIUM. Correct this when service-level requirements are known.

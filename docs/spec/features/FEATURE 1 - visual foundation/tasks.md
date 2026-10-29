# SECTION 3: TASKS

## Task 1: Define the visual system

**What to build:** Starting with a failing widget test, replace the starter app theme with the Mindful Productivity color, typography, spacing, and component defaults derived from the Stitch reference.
**Files likely affected:** `app/lib/main.dart`, `app/lib/app/activity_monitor_app.dart`, `app/lib/ui/core/theme/activity_theme.dart`, `app/test/activity_monitor_app_test.dart`
**Acceptance criteria:**
1. The app uses the specified paper, evergreen, and terracotta visual language.
2. The widget test verifies the overview can render.
3. `dart format .`, `flutter analyze`, and `flutter test` pass.
**Dependencies:** none

## Task 2: Build reusable overview components

**What to build:** Starting with failing widget tests for visible labels, add reusable card, section-header, and activity-preview widgets and compose the initial daily overview.
**Files likely affected:** `app/lib/ui/core/widgets/`, `app/lib/ui/dashboard/views/dashboard_view.dart`, `app/test/activity_monitor_app_test.dart`
**Acceptance criteria:**
1. Progress and activity content use shared visual components.
2. Status is represented by text in addition to color.
3. `dart format .`, `flutter analyze`, and `flutter test` pass.
**Dependencies:** Task 1

## Task 3: Adapt the application shell

**What to build:** Starting with a failing wide-layout test, add compact bottom navigation and wide navigation rail variants based on the available window width.
**Files likely affected:** `app/lib/ui/dashboard/views/dashboard_view.dart`, `app/test/activity_monitor_app_test.dart`, `.scratches/view_separation.md`
**Acceptance criteria:**
1. Compact and wide layouts expose all primary destinations.
2. Wide content has a bounded reading width.
3. `dart format .`, `flutter analyze`, and `flutter test` pass.
**Dependencies:** Task 2

## Review checkpoint

Review compact phone, tablet, and desktop-width windows to confirm the hierarchy remains calm, readable, and free of clipped content.

## Assumptions to review

1. The initial overview is a non-persistent design preview — Impact: MEDIUM
   Correct this if: a data-backed overview is required now.

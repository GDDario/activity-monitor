# SECTION 2: PLAN

Read constitution, architecture, conventions, design reference, SQLite ADR and
spec.md before implementation. The user's explicit no-approval instruction
supersedes the skill's document pauses; create documents sequentially and continue.

## Architecture impact and contracts

- `BuildReminderQueue` is a pure domain use case: committed task aggregates,
  clock and injected wall-time resolver → sorted bounded `TaskReminder` list.
  Reject nonexistent resolved wall times. Keep Flutter/platform APIs outside domain.
- `ReconcileReminders` coordinates TaskRepository through the existing
  EnsureTaskOccurrences callback with NotificationRepository; no repository
  depends on another. Return explicit snapshot or failure; serialize refreshes
  in the notification ViewModel and coalesce concurrent changes.
- NotificationRepository owns settings, native IDs and confirmed queue. Services
  isolate SQLite and native local notifications. Repository methods: load settings,
  save opt-in, refresh capabilities (optional permission/timing request), reconcile
  desired queue, and notification tap stream. Unexpected failures become a safe
  unavailable state; do not log personal data. Views use ViewModel commands only.
- Composition starts only after a valid profile is loaded; initialize without
  permission prompts, listen for committed task/profile changes, app resume and
  a foreground minute timer. Dispose listeners/timer and serialize pending work.
  Keep existing router/providers stable. Tap payloads carry only validated IDs
  and date; load the occurrence to validate current existence/effective date before
  Calendar navigation. Retain a cold-launch tap until setup is complete.

## Data and native integration

Migration 0007 adds a singleton notification opt-in, initially false, and stable
native IDs keyed by occurrence ID. Integer native IDs are adapter mappings, not
new domain entity IDs. Domain occurrence UUIDv7 identifiers remain unchanged.
Use constraints and transactional batch ID allocation on a worker isolate. No
existing table is rewritten; failed migrations roll back with the migration runner.

Use flutter_local_notifications 22.0.1 (compatible SDK/Android compile SDK),
timezone 0.11.x and flutter_timezone 5.1.1. Snapshot and audit the lockfile; preserve
user test_api/vector_math edits. Native backend supports Android/iOS and explicitly
reports unsupported elsewhere. Initialize Darwin with all permission requests off.
Android manifest declares notification, boot and optional exact-alarm permissions,
scheduled/boot receivers; add Java desugaring, a monochrome notification icon and
a targeted resource keep rule so release shrinking retains the dynamically named icon.
Use exactAllowWhileIdle if allowed, otherwise inexactAllowWhileIdle. Reboot handling
is delegated to the native plugin. iOS foreground delegate is configured per plugin.

Refresh time-zone data before projection. Reconcile against native pending IDs;
compare saved signatures in memory but reapply pending notifications once after
process restart to repair locale/time-zone/title changes. Remove obsolete IDs
before scheduling replacements. Never cancel delivered notifications merely to
refresh future queue. If permission is revoked/disabled, cancel pending queue.
Bound 64 reminders over 30 days; read an extra day to capture midnight lead times.
Use localized generic body with start date/time and untouched title; private Android
visibility. No exact-delivery guarantee when OS restrictions apply.

## UI and references

Bell opens a scrollable modal with title, opt-in switch, permission/timing status,
explicit permission/timing actions, refresh, upcoming items and bounded-horizon
explanation. Reuse semantic palette, typography and 48px targets. No supplied
notification-specific Stitch export exists; compare shared shell/editor with actual
exports and panel with canonical design. Replace inactive reminder copy with a
truthful instruction to check notification status via the bell.

## Testing and verification

Follow Red → minimum Green → refactor. First test projection eligibility, midnight,
exceptions, ordering/cap/DST; then SQLite migration/reopen/rollback/IDs; fake native
boundary tests for permission, idempotence/cancellation/partial retry; ViewModel
serialization, tap and cold launch; widgets for EN/PT, dark/light, keyboard,
320px doubled text and recovery. Run format, analyze and full suite. Build APK;
verify real Android permission, pending alarms and background delivery with temporary
native test fixtures, without modifying the user's stored tasks or profile.
Record actual platform evidence/limits and dependency changes. Native iOS build
cannot be claimed without an Apple host. Update task checklist after verification.

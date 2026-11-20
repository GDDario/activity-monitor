# SECTION 2: PLAN

## Required context and architecture impact

Read the constitution, architecture, conventions, ADR 0001, FEATURE 3 tasks,
FEATURE 6 profile, this specification, and the design reference before changes.
Use the existing View → ViewModel → Repository → Service flow. Domain models
own validation and calculations. Pure tracking calculations need no use case
wrapper; multi-entity SQLite mutations remain atomic in the owning service.
No new dependencies or online services are needed.

## Data model changes

- Add immutable TaskType, TrackingField, TrackingSetup, ActivityLog, and
  TrackingTimer models with field scopes, kinds, summary configuration, and
  immutable structured values.
- Task and TaskDraft gain a tracking setup snapshot. Existing tasks default to
  General. The existing SaveTask workflow saves setup alongside task metadata
  in one transaction and includes it in revision comparison.
- Migration 0008 adds task type definitions with unique normalized names,
  visibility/notices and revisions, a tracking snapshot on tasks, logs with
  task ownership and revisions, and a singleton durable timer. Catalog identifiers are fixed UUIDv7
  values and built-in field keys are stable semantic constants; new user entities use the injected UUIDv7 generator.
- Historical logs embed the field definitions needed to interpret their values.
  Retired fields remain in snapshots. Unit/kind replacement receives a new ID.
- Finish/reopen records closed date intervals in task tracking metadata;
  occurrence expansion excludes those intervals. Protected occurrences survive.
- Migration is additive. Rollback means restoring a pre-upgrade database backup;
  do not delete new tables or reset storage automatically. Upgrade tests cover
  version 7 data preservation and repeated migration.

## Application contracts

- TrackingRepository loads catalog, task tracking details/logs, and finished
  tasks; saves custom types, visibility, notices, logs, lifecycle, and timer.
- TrackingDatabase executes serializable requests in a worker with transactions,
  foreign keys, revision checks, and presentation-safe failure codes.
- TrackingViewModel owns loading/mutation state and safe errors; generated
  form models own draft values and expose domain validation to widgets.
- Composition provides the repository, clock, UUIDv7 generator, and models.
  Views never create or access repositories/services.
- Existing task revision checks protect type/setup edits. Logs check both task
  and schema revisions on creation, and log revision on update/delete.
- Loading, not found, validation, stale revision, and storage unavailable remain
  distinct; failed writes retain the draft. No raw user values enter diagnostics.

## Presentation

Extend the existing editor with type selection and generated setup fields.
Add task detail/progress and log forms, a type manager/editor, and a Finished
view. Reuse theme tokens, rounded sections, accessible controls, and scrollable
forms. Read the existing task modal/detail Stitch HTML and screenshots as visual
references. Add numeric charts with textual equivalents. Localize feature-owned
labels in en-US and pt-BR; preserve user labels. Timers persist start instants
and stopped draft durations without background permission or notification work.

## Patterns and testing strategy

Follow existing task repository compute workers, explicit constructor injection,
ChangeNotifier view models, immutable drafts, and Riverpod composition. Use
Red-Green-Refactor: confirm new tests fail before minimum production behavior,
then refactor. Cover validation/calculations, real SQLite migration/restart/
transaction conflicts, recurrence exclusions, and generated forms and navigation.
Verify compact layouts and enlarged text with rendered screenshots. Required
final gates: `dart format .`, `flutter analyze`, `flutter test`.

## Security and performance

Data stays on the device under the existing profile boundary. Participant links
are preserved; no remote permissions or attribution are implied. Reject invalid
external input in domain validation; enforce identity, ownership and revisions
again inside persistence transactions. Batch task history loads and index logs
by task and recorded instant. Storage failure never resets the database.

## Approval

The user approved CF01–CF18 and waived further document approval gates.
Implementation choices above follow the existing repository patterns.

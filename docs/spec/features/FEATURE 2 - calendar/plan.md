# SECTION 2: PLAN

## Architecture impact
Read the constitution, architecture, conventions, design reference and ADR 0001 before implementation. This spec is authoritative and must be updated before behavior changes. Calendar View → ViewModel → CalendarRepository → SQLite service is a single-source read workflow; no use case is needed. Construct dependencies at the app boundary. Use the existing shell and theme.

Startup eagerly starts an injected database initialization provider at the app composition boundary. It resolves the native application-support path, initializes the database in an isolate, and exposes the same initialization result to calendar loading. Startup failures are reported without sensitive details and calendar loading receives the failure instead of creating an empty data set.

## Data model changes
Calendar entries are local, materialized occurrences, with id, title, local date, cadence and participant links; participants have id and display name. IDs are UUIDv7 supplied through the existing injected UUID dependency when future creation is introduced. Create version 1 with constrained entries, participants and junction tables and foreign keys. Fresh installations apply migrations transactionally using SQLite user_version. Version 1 adds tables only; rollback drops them only after explicit data backup, and future destructive migrations must define backup and data transformation. Native databases use an application-support directory; web storage is unavailable until separately specified. No authentication or sync is introduced.

Keep version 1 schema unchanged for existing installations. Register migrations in ascending version order, acquire a write transaction before checking user_version, reject newer schemas, and roll back schema and version together on failure. Enable foreign keys for every connection. Close connections after initialization or reads. Development recreation is manual and explicitly destructive, performed only while the app is stopped; never reset automatically on migration failure.

Create a Laravel-style migrations table with a unique migration name and batch number; reconcile legacy user_version 1 by recording the already-applied first migration before running migration 2. Keep user_version synchronized for compatibility and reject inconsistent histories. Migration 2 invokes an injected calendar seeder inside the migration transaction. Inject the clock and UUIDv7 generator so tests can fix dates and IDs; seed clearly labeled examples for the local month, including today, solo and collaborative entries with daily, weekly and one-time cadence. Examples are persisted once and are not regenerated in later months. Explicitly requested examples are installed on existing and new databases, including release builds, and are labeled as examples.

Each migration lives in its own file in `app/lib/data/services/database/migrations/`, with the same zero-padded number in its filename and class name as specified in the project conventions. Keep the stored migration identifiers and SQL unchanged when reorganizing existing migrations.

## Application contracts
- CalendarRepository.load(): returns entries and participants or an explicit unavailable result; it is the source of truth.
- SQLite service opens the local database, enables foreign keys, migrates and reads entries and participants; errors are translated to presentation-safe unavailable state.
- Calendar ViewModel owns date, mode, filters, loaded data and commands; the View only renders and forwards input.

## Patterns to follow
Use ApplicationShell, ScreenTitleBar, ActivityTheme, Riverpod composition and Flutter localization. Follow the supplied Stitch calendar layout and design reference.

## Testing strategy
Use red-green-refactor for each new behavior. Test date boundaries and filters independently; test migrations and real SQLite reads; use repository fakes for ViewModel and widget presentation tests covering localization, focus, accessibility and responsive sizes. Run dart format ., flutter analyze and flutter test from app. Compare against the Stitch image and HTML.

## Security and performance constraints
Treat persisted input as untrusted, enforce schema constraints, avoid secrets and sensitive logs, and show safe errors. This issue uses a single local user, with no remote authorization or encryption. Avoid lengthy synchronous SQLite work on the UI isolate.

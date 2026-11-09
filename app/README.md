# app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local database and development reset

On native platforms the app creates `activity_monitor.db` in the platform's
application-support directory when the app starts. Startup applies pending
SQLite migrations before calendar data can be read. Web persistence is not yet
configured. If initialization fails, the app keeps the existing database and
the calendar reports that its data is unavailable; it never automatically
deletes the database or retries until the app restarts.

Migrations are registered in `lib/data/services/database/migrations.dart` and
recorded by name and batch in the `migrations` table. SQLite `user_version` is
kept in sync for compatibility; existing version-1 databases are recorded in
the new history before pending migrations run. Add a new consecutive migration
in its own file under `lib/data/services/database/migrations/`, using matching
zero-padded numbers in the filename and class name, such as
`migration_0001_create_calendar_tables.dart` and
`Migration0001CreateCalendarTables`. Register it in numeric order. Do not edit
an already-released migration or rename its recorded identifier. A migration can accept a
seeder callback, which runs after its table operations in the same transaction.
If either fails, schema, seed data, and migration history roll back together.
Plan a data transformation and backup before any destructive schema change; a
transaction rollback is not a downgrade of a committed database.

Migration 2 inserts calendar examples, labeled `Example:`, in the local month
when it first runs. It applies to both existing and fresh databases, including
release builds. The examples include today, multiple cadences, and a participant.
The migration runs once per database: opening the app in a later month does not
regenerate the examples. Recreating the database runs it again for that month.

Migration 3 adds a constrained completion flag. Existing entries and new
entries without an explicit status are pending. The calendar counts pending and
done entries for the selected day and active filters; changing completion status
is outside the calendar feature. Downgrading requires a backup and table rebuild
and would discard stored completion status.

## Task cards, editor, and recurring schedules

The task feature adds local creation/editing to Today and Calendar. Both screens
use the same cards and actions. Today derives its filters, pending/done counts
and progress from stored occurrences. Calendar retains its selected date, mode,
cadence filter and participant filter when committed changes refresh its data.

Migration 4 (`0004_create_task_tables`) replaces calendar entries with canonical
`tasks` and `task_occurrences`, plus tag, checklist, participant-link and schedule
history tables. Existing entry IDs, title text, dates, cadence labels, completion
and participant links are preserved. Each legacy entry becomes an independent
task with one occurrence. Its daily/weekly label does not silently enable new
repeats: the editor offers explicit opt-in. Example records keep their labels
and are not regenerated. Unknown historical creation/completion times stay
unknown rather than receiving invented timestamps.

New daily and weekly tasks materialize only requested date intervals. An
occurrence keeps its original scheduled slot when postponed; its effective date
determines agenda placement. Deleting one occurrence retains a tombstone so
reloading or restarting cannot regenerate it. It does not delete the series.
Completion, reopening, postponement and deletion affect the selected occurrence;
subtask completion is independent from its parent.

The editor distinguishes shared details/checklist definitions and scheduling
defaults from the selected occurrence's date/time override. Shared details
apply to the task's cards, including past cards. Recurrence edits take effect
from tomorrow and preserve past/today, completed and explicitly modified slots;
historical rule snapshots reconstruct previously unvisited dates. Changing to
one-time stops further repeats from the effective boundary. Daily streaks use
original scheduled dates, including intentional backfilled completions, and
never count future dates.

Timed tasks can save reminder preferences, but this release does not request
notification permission, schedule alerts, or play sounds. The UI labels these
preferences as inactive. Custom recurrence, participant assignment/invitations,
remote synchronization, authentication, storage encryption and web persistence
are not introduced.

Completion and deletion offer the latest five-active-second Undo window.
Remaining time survives navigation between Today and Calendar, uses elapsed
time independent of device-clock changes, and pauses/extends for accessible
interaction. Restarting closes the recovery window while preserving committed
data. Conditional task/occurrence revisions prevent stale editors or Undo from
overwriting newer changes.

All aggregate writes and migrations are transactional. A failed write preserves
the editor draft; a failed migration preserves the pre-upgrade schema, data and
history. No startup error automatically resets the database. A successful
version-4 database cannot be opened by an older app expecting calendar-entry
tables. Before upgrading data that must be recoverable, stop the app and retain
a consistent pre-upgrade database backup, including any WAL/SHM companions.
Operational rollback requires restoring that backup with the matching older
app while stopped; preserve/export post-upgrade data before any deliberate
conversion. There is no automatic destructive down migration.

Feature contracts and verification checklists are in
[`../docs/spec/features/FEATURE 3 - tasks/`](../docs/spec/features/FEATURE%203%20-%20tasks/).
Run `dart format .`, `flutter analyze`, and `flutter test` from this directory.
For runtime inspection start Flutter with `--print-dtd`; from a worktree root,
the repository's `.opencode/skills/git-worktree/scripts/run_flutter.sh` helper
allocates isolated runtime ports. Screenshots and working artifacts belong in
that worktree's `.scratches/` directory.

To recreate a development database, **stop the app first** and move
`activity_monitor.db` and any `activity_monitor.db-wal` and
`activity_monitor.db-shm` files out of the application-support directory to a
backup location. Restarting the app creates a fresh database and reapplies all
migrations. This resets all locally stored application data; restore the backup
with the app stopped if it was needed. Never remove files from a running app.

On Linux the directory is normally
`~/.local/share/com.example.app/` (or `$XDG_DATA_HOME/com.example.app/` when
`XDG_DATA_HOME` is set). The path provider may use a legacy executable-named
directory if it already exists. Other platforms use their own application
support directory; locate it through the platform's app-container tools. On a
disposable Android emulator, clearing the app's storage is another option, but
it removes all app data, not just the database.

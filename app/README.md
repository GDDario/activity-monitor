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
tracked using SQLite `user_version`. Add a new consecutive migration instead
of editing an already-released migration. The migration transaction rolls back
if a step fails. Plan a data transformation and backup before any destructive
schema change; a rollback of the transaction is not a downgrade of a committed
database.

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

import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/database_migration.dart';

class Migration0007CreateNotificationSettings extends DatabaseMigration {
  const Migration0007CreateNotificationSettings()
    : super(7, _apply, name: '0007_create_notification_settings');
  static void _apply(Database db) {
    db.execute(
      'CREATE TABLE notification_settings(slot INTEGER PRIMARY KEY CHECK(slot=1),enabled INTEGER NOT NULL CHECK(enabled IN(0,1)))',
    );
    db.execute('INSERT INTO notification_settings VALUES(1,0)');
    db.execute(
      "CREATE TABLE notification_ids(id INTEGER PRIMARY KEY AUTOINCREMENT CHECK(id BETWEEN 1 AND 2147483647),occurrence_id TEXT NOT NULL UNIQUE CHECK(length(trim(occurrence_id)) BETWEEN 1 AND 100))",
    );
  }
}

import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/database_migration.dart';

class Migration0006CreateLocalProfile extends DatabaseMigration {
  const Migration0006CreateLocalProfile()
    : super(6, _apply, name: '0006_create_local_profile');
  static void _apply(Database db) {
    db.execute('''CREATE TABLE local_profile (
    slot INTEGER PRIMARY KEY CHECK(slot=1),
    id TEXT NOT NULL UNIQUE CHECK(length(trim(id))>0),
    display_name TEXT NOT NULL CHECK(display_name=trim(display_name) AND length(display_name) BETWEEN 1 AND 100),
    appearance TEXT NOT NULL CHECK(appearance IN ('system','light','dark')),
    language TEXT NOT NULL CHECK(language IN ('device','enUs','ptBr')),
    avatar_png BLOB CHECK(avatar_png IS NULL OR (typeof(avatar_png)='blob' AND length(avatar_png) BETWEEN 1 AND 5242880)),
    revision INTEGER NOT NULL CHECK(revision>=0)
  )''');
  }
}

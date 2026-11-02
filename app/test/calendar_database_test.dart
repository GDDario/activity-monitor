import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/migrations.dart';

void main() {
  test('migration creates constrained calendar tables and preserves records', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    migrateDatabase(db);
    expect(db.select('PRAGMA user_version').single.values.single, 2);
    db.execute(
      "INSERT INTO calendar_entries VALUES ('id', 'Walk', '2024-02-29', 'daily')",
    );
    expect(
      db
          .select("SELECT title FROM calendar_entries WHERE id = 'id'")
          .single['title'],
      'Walk',
    );
    expect(
      () => db.execute(
        "INSERT INTO calendar_entries VALUES ('bad', 'X', '2024-01-01', 'invalid')",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        "INSERT INTO calendar_entry_participants VALUES ('missing', 'missing')",
      ),
      throwsA(isA<SqliteException>()),
    );
    migrateDatabase(db);
    expect(
      db.select("SELECT * FROM calendar_entries WHERE id = 'id'").length,
      1,
    );
  });
}

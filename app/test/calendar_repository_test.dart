import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/calendar_database.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/repositories/calendar_repository.dart';

void main() {
  test('reads entries with participants from the database', () async {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    migrateDatabase(db);
    db.execute(
      "INSERT INTO calendar_entries (id, title, date, cadence) VALUES ('e', 'Walk', '2024-02-29', 'daily')",
    );
    db.execute("INSERT INTO calendar_participants VALUES ('p', 'Lee')");
    db.execute("INSERT INTO calendar_entry_participants VALUES ('e', 'p')");
    final result = await CalendarRepository(CalendarDatabase(() async => db))
        .load();
    final entry = result.entries.singleWhere((entry) => entry.id == 'e');
    expect(entry.title, 'Walk');
    expect(entry.participantIds, ['p']);
    expect(
      result.participants
          .singleWhere((participant) => participant.id == 'p')
          .name,
      'Lee',
    );
  });
}

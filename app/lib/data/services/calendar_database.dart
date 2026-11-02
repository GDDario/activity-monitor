import 'package:sqlite3/sqlite3.dart';
import 'package:app/domain/models/calendar_data.dart';

class CalendarDatabase {
  CalendarDatabase(this.open);
  final Future<Database> Function() open;

  Future<CalendarData> load() async {
    final db = await open();
    final participants = db
        .select('SELECT id, name FROM calendar_participants ORDER BY name')
        .map((r) => CalendarParticipant(r['id'] as String, r['name'] as String))
        .toList();
    final links = db.select(
      'SELECT entry_id, participant_id FROM calendar_entry_participants',
    );
    final entries = db
        .select(
          'SELECT id, title, date, cadence FROM calendar_entries ORDER BY date, title',
        )
        .map((r) {
          final id = r['id'] as String;
          return CalendarEntry(
            id: id,
            title: r['title'] as String,
            date: DateTime.parse(r['date'] as String),
            cadence: switch (r['cadence']) {
              'daily' => CalendarCadence.daily,
              'weekly' => CalendarCadence.weekly,
              _ => CalendarCadence.oneTime,
            },
            participantIds: links
                .where((link) => link['entry_id'] == id)
                .map((link) => link['participant_id'] as String)
                .toList(),
          );
        })
        .toList();
    return CalendarData(entries, participants);
  }
}

import 'package:sqlite3/sqlite3.dart';

class CalendarSeeder {
  const CalendarSeeder({required this.now, required this.newId});

  final DateTime Function() now;
  final String Function() newId;

  void run(Database db) {
    final today = now().toLocal();
    final lastDay = DateTime(today.year, today.month + 1, 0).day;
    String date(int day) =>
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final participant = newId();
    db.execute('INSERT INTO calendar_participants (id, name) VALUES (?, ?)', [
      participant,
      'Example: Alex',
    ]);
    void entry(
      String title,
      int day,
      String cadence, {
      bool collaborative = false,
    }) {
      final id = newId();
      db.execute(
        'INSERT INTO calendar_entries (id, title, date, cadence) VALUES (?, ?, ?, ?)',
        [id, 'Example: $title', date(day), cadence],
      );
      if (collaborative) {
        db.execute(
          'INSERT INTO calendar_entry_participants (entry_id, participant_id) VALUES (?, ?)',
          [id, participant],
        );
      }
    }

    entry('Mindful walk', today.day, 'daily');
    entry('Weekly check-in', today.day, 'weekly', collaborative: true);
    entry('Monthly reflection', lastDay, 'one-time');
    entry('Morning reading', 1, 'daily');
  }
}

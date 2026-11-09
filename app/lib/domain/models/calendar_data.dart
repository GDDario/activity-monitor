import 'package:app/domain/models/task.dart';

enum CalendarCadence { daily, weekly, oneTime }

class CalendarEntry {
  const CalendarEntry({
    required this.id,
    required this.title,
    required this.date,
    required this.cadence,
    required this.participantIds,
    this.isDone = false,
    this.taskAggregate,
  });
  final String id;
  final String title;
  final DateTime date;
  final CalendarCadence cadence;
  final List<String> participantIds;
  final bool isDone;
  final TaskAggregate? taskAggregate;
}

class CalendarParticipant {
  const CalendarParticipant(this.id, this.name);
  final String id;
  final String name;
}

class CalendarData {
  const CalendarData(this.entries, this.participants);
  final List<CalendarEntry> entries;
  final List<CalendarParticipant> participants;
}

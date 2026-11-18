import 'package:app/domain/models/task.dart';
import 'package:app/domain/value_objects/local_date.dart';

enum DailyScopeKind { all, solo, shared, companion }

final class DailyTaskScope {
  const DailyTaskScope.all() : kind = DailyScopeKind.all, companionId = null;
  const DailyTaskScope.solo() : kind = DailyScopeKind.solo, companionId = null;
  const DailyTaskScope.shared()
    : kind = DailyScopeKind.shared,
      companionId = null;
  const DailyTaskScope.companion(String id)
    : assert(id != ''),
      kind = DailyScopeKind.companion,
      companionId = id;
  final DailyScopeKind kind;
  final String? companionId;
  @override
  bool operator ==(Object other) =>
      other is DailyTaskScope &&
      other.kind == kind &&
      other.companionId == companionId;
  @override
  int get hashCode => Object.hash(kind, companionId);
}

enum DailyAgendaPeriod { morning, afternoonEvening, anyTime }

final class DailyAgendaSection {
  DailyAgendaSection(this.period, List<TaskAggregate> entries)
    : entries = List.unmodifiable(entries);
  final DailyAgendaPeriod period;
  final List<TaskAggregate> entries;
}

final class DailyProgress {
  const DailyProgress({
    required this.total,
    required this.completed,
    required this.collaborative,
    required this.next,
  });
  final int total, completed, collaborative;
  final TaskAggregate? next;
  int get pending => total - completed;
  double get fraction => total == 0 ? 0 : completed / total;
  int get percentage => (fraction * 100).round();
}

final class DailyOverview {
  DailyOverview({
    required this.day,
    required this.scope,
    required List<TaskParticipant> companions,
    required List<TaskAggregate> entries,
    required List<DailyAgendaSection> sections,
    required this.progress,
  }) : companions = List.unmodifiable(companions),
       entries = List.unmodifiable(entries),
       sections = List.unmodifiable(sections);
  final LocalDate day;
  final DailyTaskScope scope;
  final List<TaskParticipant> companions;
  final List<TaskAggregate> entries;
  final List<DailyAgendaSection> sections;
  final DailyProgress progress;
}

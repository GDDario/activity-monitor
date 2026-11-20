import 'package:app/domain/models/daily_overview.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_ordering.dart';
import 'package:app/domain/value_objects/local_date.dart';

final class BuildDailyOverview {
  const BuildDailyOverview();

  DailyOverview execute({
    required List<TaskAggregate> entries,
    required DateTime now,
    DailyTaskScope scope = const DailyTaskScope.all(),
  }) {
    final local = now.toLocal();
    final day = LocalDate(local.year, local.month, local.day);
    final daily = entries
        .where(
          (a) => !a.occurrence.isDeleted && a.occurrence.effectiveDate == day,
        )
        .toList();
    final people = <String, TaskParticipant>{};
    for (final a in daily) {
      for (final p in a.task.participants) {
        people[p.id] = p;
      }
    }
    final companions = people.values.toList()
      ..sort((a, b) {
        final name = a.name.compareTo(b.name);
        return name == 0 ? a.id.compareTo(b.id) : name;
      });
    final effectiveScope =
        scope.kind == DailyScopeKind.companion &&
            !people.containsKey(scope.companionId)
        ? const DailyTaskScope.all()
        : scope;
    final visible =
        daily
            .where(
              (a) => switch (effectiveScope.kind) {
                DailyScopeKind.all => true,
                DailyScopeKind.solo => a.task.participants.isEmpty,
                DailyScopeKind.shared => a.task.participants.isNotEmpty,
                DailyScopeKind.companion => a.task.participants.any(
                  (p) => p.id == effectiveScope.companionId,
                ),
              },
            )
            .toList()
          ..sort(compareTaskAggregates);
    final sections = <DailyAgendaSection>[];
    for (final period in DailyAgendaPeriod.values) {
      final group = visible.where((a) => _period(a) == period).toList();
      if (group.isNotEmpty) sections.add(DailyAgendaSection(period, group));
    }
    final minute = local.hour * 60 + local.minute;
    final upcoming = visible.where(
      (a) =>
          !a.occurrence.completed &&
          a.occurrence.timeWindow != null &&
          a.occurrence.timeWindow!.startMinute >= minute,
    );
    return DailyOverview(
      day: day,
      scope: effectiveScope,
      companions: companions,
      entries: visible,
      sections: sections,
      progress: DailyProgress(
        total: visible.length,
        completed: visible.where((a) => a.occurrence.completed).length,
        collaborative: visible
            .where((a) => a.task.participants.isNotEmpty)
            .length,
        next: upcoming.firstOrNull,
      ),
    );
  }

  DailyAgendaPeriod _period(TaskAggregate a) {
    final start = a.occurrence.timeWindow?.startMinute;
    if (start != null) {
      return start < 720
          ? DailyAgendaPeriod.morning
          : DailyAgendaPeriod.afternoonEvening;
    }
    return switch (a.task.schedule.dayPeriod) {
      DayPeriod.morning => DailyAgendaPeriod.morning,
      DayPeriod.afternoon ||
      DayPeriod.evening => DailyAgendaPeriod.afternoonEvening,
      null => DailyAgendaPeriod.anyTime,
    };
  }
}

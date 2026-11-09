import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/use_cases/postpone_task_occurrence.dart';

import 'helpers/task_action_fixture.dart';

void main() {
  late TaskActionFixture fixture;
  setUp(() => fixture = TaskActionFixture());
  tearDown(() => fixture.repository.dispose());
  test('moves selected original slot onto local tomorrow without merging the normal slot', () async {
    final before = fixture.occurrence;
    final task = fixture.repository.tasks[fixture.taskId];
    final result = await PostponeTaskOccurrence(
      fixture.repository,
      now: () => DateTime(2026, 12, 31, 12),
    ).execute(fixture.id, fixture.expected);
    expect(result.isSuccess, isTrue);
    expect(fixture.occurrence.id, before.id);
    expect(fixture.occurrence.scheduledDate, before.scheduledDate);
    expect(fixture.occurrence.effectiveDate, LocalDate(2027, 1, 1));
    expect(fixture.occurrence.isScheduleException, isTrue);
    expect(fixture.occurrence.timeWindow, before.timeWindow);
    expect(fixture.occurrence.reminder, before.reminder);
    expect(fixture.occurrence.subtaskStates, before.subtaskStates);
    expect(fixture.repository.tasks[fixture.taskId], same(task));
    expect(fixture.repository.occurrences, hasLength(2));
    expect(
      result.value!.affectedDates,
      containsAll([LocalDate(2026, 12, 31), LocalDate(2027, 1, 1)]),
    );
  });
  test('already due tomorrow returns informational no-op', () async {
    fixture.repository.occurrences[fixture.id] = fixture.occurrence.copyWith(
      effectiveDate: LocalDate(2027, 1, 1),
    );
    final result = await PostponeTaskOccurrence(
      fixture.repository,
      now: () => DateTime(2026, 12, 31),
    ).execute(fixture.id, fixture.expected);
    expect(result.value!.changed, isFalse);
    expect(fixture.repository.mutationAttempts, 0);
  });
  test('completed occurrence cannot be postponed', () async {
    fixture.repository.occurrences[fixture.id] = fixture.occurrence.copyWith(
      completed: true,
    );
    final result = await PostponeTaskOccurrence(
      fixture.repository,
      now: () => DateTime(2026, 12, 31),
    ).execute(fixture.id, fixture.expected);
    expect(result.failure!.code, TaskFailureCode.invalidTransition);
    expect(fixture.repository.mutationAttempts, 0);
  });
  for (final today in [
    LocalDate(2024, 2, 28),
    LocalDate(2024, 2, 29),
    LocalDate(2026, 4, 30),
  ]) {
    test('local tomorrow respects calendar boundary $today', () async {
      final result = await PostponeTaskOccurrence(
        fixture.repository,
        now: () => DateTime(today.year, today.month, today.day, 12),
      ).execute(fixture.id, fixture.expected);
      expect(result.isSuccess, isTrue);
      expect(fixture.occurrence.effectiveDate, today.addDays(1));
    });
  }
}

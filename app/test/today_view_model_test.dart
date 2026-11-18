import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/ui/dashboard/view_models/today_view_model.dart';

void main() {
  test(
    'Today counts durable occurrences after participant filtering',
    () async {
      final date = LocalDate(2026, 11, 7);
      TaskAggregate entry(String id, bool shared, bool complete) =>
          TaskAggregate(
            task: Task(
              id: TaskId(id),
              title: TaskTitle(id),
              schedule: TaskSchedule(
                cadence: TaskCadence.oneTime,
                recurrenceEnabled: false,
                startDate: date,
              ),
              participants: shared ? [const TaskParticipant('p', 'Alex')] : [],
            ),
            occurrence: TaskOccurrence(
              id: OccurrenceId(id),
              taskId: TaskId(id),
              scheduledDate: date,
              effectiveDate: date,
              completed: complete,
            ),
          );
      final model = TodayViewModel(
        clock: () => DateTime(2026, 11, 7),
        load: (_) async => TaskSuccess([
          entry('Solo', false, false),
          entry('Shared', true, true),
        ]),
      );
      addTearDown(model.dispose);
      await model.load();
      expect(model.pendingCount, 1);
      expect(model.doneCount, 1);
      model.setFilter(TodayFilter.shared);
      expect(model.visible.single.task.title.value, 'Shared');
      expect(model.pendingCount, 0);
      expect(model.doneCount, 1);
    },
  );
}

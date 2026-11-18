import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/subtask_id.dart';
import 'package:app/domain/value_objects/tag_id.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/domain/value_objects/subtask_title.dart';
import 'package:app/domain/value_objects/tag_name.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';

import 'fake_task_repository.dart';

class ActionTaskRepository extends FakeTaskRepository {
  int mutationAttempts = 0;
  TaskFailure? mutationFailure;
  TaskFailure? restoreFailure;

  @override
  Future<TaskResult<TaskMutationReceipt>> applyOccurrenceChange(
    PreparedOccurrenceChange change,
  ) async {
    mutationAttempts++;
    if (mutationFailure != null) {
      return TaskError(mutationFailure!);
    }
    return super.applyOccurrenceChange(change);
  }

  @override
  Future<TaskResult<TaskMutationReceipt>> restoreOccurrence(
    TaskUndoSnapshot snapshot,
  ) async {
    if (restoreFailure != null) {
      return TaskError(restoreFailure!);
    }
    return super.restoreOccurrence(snapshot);
  }
}

class TaskActionFixture {
  TaskActionFixture() {
    repository.tasks[taskId] = Task(
      id: taskId,
      title: TaskTitle('Read'),
      notes: 'Keep notes',
      priority: TaskPriority.high,
      revision: 3,
      schedule: TaskSchedule(
        cadence: TaskCadence.daily,
        recurrenceEnabled: true,
        startDate: date,
      ),
      tags: [TaskTag(id: TagId('tag'), name: TagName('Books'))],
      participants: [const TaskParticipant('person', 'Alex')],
      subtasks: [
        TaskSubtask(id: subtaskId, title: SubtaskTitle('Chapter'), position: 0),
      ],
    );
    repository.occurrences[id] = TaskOccurrence(
      id: id,
      taskId: taskId,
      scheduledDate: date,
      effectiveDate: date,
      timeWindow: TimeWindow(900, 960),
      reminder: ReminderPreference(15),
      revision: 4,
      subtaskStates: {subtaskId: true},
    );
    repository.occurrences[otherId] = TaskOccurrence(
      id: otherId,
      taskId: taskId,
      scheduledDate: date.addDays(1),
      effectiveDate: date.addDays(1),
    );
  }
  final repository = ActionTaskRepository();
  final taskId = TaskId('task');
  final id = OccurrenceId('selected');
  final otherId = OccurrenceId('tomorrow');
  final subtaskId = SubtaskId('child');
  final date = LocalDate(2026, 12, 31);
  TaskOccurrence get occurrence => repository.occurrences[id]!;
  ExpectedRevisions get expected => ExpectedRevisions(
    taskId: taskId,
    taskRevision: repository.tasks[taskId]!.revision,
    occurrenceRevision: occurrence.revision,
  );
}

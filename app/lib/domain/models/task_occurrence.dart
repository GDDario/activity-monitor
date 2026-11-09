import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/subtask_id.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';

const _unchanged = Object();

class TaskOccurrence {
  TaskOccurrence({
    required this.id,
    required this.taskId,
    required this.scheduledDate,
    required this.effectiveDate,
    this.timeWindow,
    this.reminder = const ReminderPreference.off(),
    this.completed = false,
    this.completedAtUtc,
    this.deletedAtUtc,
    this.isScheduleException = false,
    this.revision = 0,
    Map<SubtaskId, bool> subtaskStates = const {},
  }) : subtaskStates = Map.unmodifiable(subtaskStates) {
    if (revision < 0 ||
        !completed && completedAtUtc != null ||
        timeWindow == null && reminder.minutesBefore != null) {
      throw ArgumentError('Invalid occurrence state');
    }
  }
  final OccurrenceId id;
  final TaskId taskId;
  final LocalDate scheduledDate;
  final LocalDate effectiveDate;
  final TimeWindow? timeWindow;
  final ReminderPreference reminder;
  final bool completed;
  final DateTime? completedAtUtc;
  final DateTime? deletedAtUtc;
  final bool isScheduleException;
  final int revision;
  final Map<SubtaskId, bool> subtaskStates;
  bool get isDeleted => deletedAtUtc != null;
  TaskOccurrence copyWith({
    LocalDate? effectiveDate,
    Object? timeWindow = _unchanged,
    ReminderPreference? reminder,
    bool? completed,
    Object? completedAtUtc = _unchanged,
    Object? deletedAtUtc = _unchanged,
    bool? isScheduleException,
    int? revision,
    Map<SubtaskId, bool>? subtaskStates,
  }) => TaskOccurrence(
    id: id,
    taskId: taskId,
    scheduledDate: scheduledDate,
    effectiveDate: effectiveDate ?? this.effectiveDate,
    timeWindow: identical(timeWindow, _unchanged)
        ? this.timeWindow
        : timeWindow as TimeWindow?,
    reminder: reminder ?? this.reminder,
    completed: completed ?? this.completed,
    completedAtUtc: identical(completedAtUtc, _unchanged)
        ? this.completedAtUtc
        : completedAtUtc as DateTime?,
    deletedAtUtc: identical(deletedAtUtc, _unchanged)
        ? this.deletedAtUtc
        : deletedAtUtc as DateTime?,
    isScheduleException: isScheduleException ?? this.isScheduleException,
    revision: revision ?? this.revision,
    subtaskStates: subtaskStates ?? this.subtaskStates,
  );
}

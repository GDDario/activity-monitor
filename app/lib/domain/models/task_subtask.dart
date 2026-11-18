import 'package:app/domain/value_objects/subtask_id.dart';
import 'package:app/domain/value_objects/subtask_title.dart';

class TaskSubtask {
  const TaskSubtask({
    required this.id,
    required this.title,
    required this.position,
    this.active = true,
  });
  final SubtaskId id;
  final SubtaskTitle title;
  final int position;
  final bool active;
}

class DraftSubtask {
  const DraftSubtask({
    required this.id,
    required this.title,
    this.completed = false,
  });
  final SubtaskId id;
  final String title;
  final bool completed;
  DraftSubtask copyWith({String? title, bool? completed}) => DraftSubtask(
    id: id,
    title: title ?? this.title,
    completed: completed ?? this.completed,
  );
}

import 'package:app/domain/models/task.dart';

int compareTaskAggregates(TaskAggregate a, TaskAggregate b) {
  final completion = (a.occurrence.completed ? 1 : 0).compareTo(
    b.occurrence.completed ? 1 : 0,
  );
  if (completion != 0) return completion;
  final time = (a.occurrence.timeWindow?.startMinute ?? 1440).compareTo(
    b.occurrence.timeWindow?.startMinute ?? 1440,
  );
  if (time != 0) return time;
  final title = a.task.title.value.compareTo(b.task.title.value);
  return title != 0
      ? title
      : a.occurrence.id.value.compareTo(b.occurrence.id.value);
}

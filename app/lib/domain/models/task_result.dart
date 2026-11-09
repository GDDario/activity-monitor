enum TaskFailureCode {
  validation,
  notFound,
  deleted,
  staleRevision,
  invalidTransition,
  undoExpired,
  undoReplaced,
  storageUnavailable,
}

class TaskFailure {
  TaskFailure(this.code, {Map<String, String> fields = const {}})
    : fields = Map.unmodifiable(fields);
  TaskFailure.validation(Map<String, String> fields)
    : this(TaskFailureCode.validation, fields: fields);
  final TaskFailureCode code;
  final Map<String, String> fields;
}

sealed class TaskResult<T> {
  const TaskResult();
  bool get isSuccess => this is TaskSuccess<T>;
  T? get value => switch (this) {
    TaskSuccess<T>(:final data) => data,
    _ => null,
  };
  TaskFailure? get failure => switch (this) {
    TaskError<T>(:final error) => error,
    _ => null,
  };
}

class TaskSuccess<T> extends TaskResult<T> {
  const TaskSuccess(this.data);
  final T data;
}

class TaskError<T> extends TaskResult<T> {
  const TaskError(this.error);
  final TaskFailure error;
}

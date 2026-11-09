import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';

enum TaskAction { complete, reopen, postpone, delete }

typedef OccurrenceCommand = Future<TaskResult<TaskMutationReceipt>> Function(
  OccurrenceId id,
  ExpectedRevisions expected,
);

class TaskActionsViewModel extends ChangeNotifier {
  TaskActionsViewModel({
    required this.commands,
    required this.undo,
    Duration Function()? elapsed,
  }) {
    _stopwatch.start();
    _elapsed = elapsed ?? (() => _stopwatch.elapsed);
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => refreshRemaining(),
    );
  }

  final Map<TaskAction, OccurrenceCommand> commands;
  final Future<TaskResult<TaskMutationReceipt>> Function(TaskUndoSnapshot) undo;
  final _stopwatch = Stopwatch();
  late final Duration Function() _elapsed;
  Timer? _timer;
  final Set<OccurrenceId> _pending = {};
  TaskFailure? failure;
  String? messageKey;
  TaskUndoSnapshot? _snapshot;
  Duration _remaining = Duration.zero;
  Duration _lastElapsed = Duration.zero;
  bool _focused = false;
  bool _accessibleNavigation = false;
  bool _undoPending = false;
  bool _disposed = false;
  int _sequence = 0;

  bool isPending(OccurrenceId id) => _pending.contains(id);
  bool get isUndoPending => _undoPending;
  bool get canUndo =>
      !_disposed && _snapshot != null && _remaining > Duration.zero;
  int get remainingSeconds => (_remaining.inMilliseconds / 1000).ceil();
  int get undoSequence => _sequence;

  void refreshRemaining() {
    if (_disposed || _snapshot == null) return;
    final now = _elapsed();
    final elapsed = now - _lastElapsed;
    _lastElapsed = now;
    if (_focused || _accessibleNavigation || _undoPending) return;
    final previous = remainingSeconds;
    _remaining -= elapsed.isNegative ? Duration.zero : elapsed;
    if (_remaining <= Duration.zero) {
      _remaining = Duration.zero;
      _snapshot = null;
    }
    if (previous != remainingSeconds) notifyListeners();
  }

  void setFocused(bool focused) {
    refreshRemaining();
    _focused = focused;
  }

  void setAccessibleNavigation(bool enabled) {
    refreshRemaining();
    _accessibleNavigation = enabled;
  }

  Future<void> perform(TaskAction action, TaskAggregate aggregate) async {
    final id = aggregate.occurrence.id;
    if (_disposed || _pending.contains(id)) return;
    final command = commands[action];
    if (command == null) return;
    _pending.add(id);
    failure = null;
    notifyListeners();
    TaskResult<TaskMutationReceipt> result;
    try {
      result = await command(id, aggregate.expected);
    } catch (_) {
      result = TaskError(TaskFailure(TaskFailureCode.storageUnavailable));
    }
    if (_disposed) return;
    _pending.remove(id);
    failure = result.failure;
    final receipt = result.value;
    if (receipt != null && receipt.changed) {
      refreshRemaining();
      final nextMessage = switch (action) {
        TaskAction.complete => 'taskCompleted',
        TaskAction.reopen => 'taskReopened',
        TaskAction.postpone => 'taskPostponed',
        TaskAction.delete => 'taskDeleted',
      };
      if (receipt.undo != null) {
        _snapshot = receipt.undo;
        _remaining = const Duration(seconds: 5);
        _lastElapsed = _elapsed();
        _sequence++;
        messageKey = nextMessage;
      } else if (!canUndo || _snapshot!.before.id == id) {
        if (_snapshot != null) _sequence++;
        _snapshot = null;
        _remaining = Duration.zero;
        messageKey = nextMessage;
      }
    }
    notifyListeners();
  }

  Future<void> undoLatest({int? sequence}) async {
    if (_disposed || _undoPending) return;
    refreshRemaining();
    if (sequence != null && sequence != _sequence) {
      failure = TaskFailure(TaskFailureCode.undoReplaced);
      notifyListeners();
      return;
    }
    final snapshot = _snapshot;
    if (!canUndo || snapshot == null) {
      failure = TaskFailure(TaskFailureCode.undoExpired);
      notifyListeners();
      return;
    }
    final id = snapshot.before.id;
    if (_pending.contains(id)) return;
    final currentSequence = _sequence;
    _pending.add(id);
    _undoPending = true;
    failure = null;
    notifyListeners();
    TaskResult<TaskMutationReceipt> result;
    try {
      result = await undo(snapshot);
    } catch (_) {
      result = TaskError(TaskFailure(TaskFailureCode.storageUnavailable));
    }
    if (_disposed) return;
    _lastElapsed = _elapsed();
    _undoPending = false;
    _pending.remove(id);
    if (currentSequence == _sequence) {
      failure = result.failure;
      final code = failure?.code;
      final invalid =
          code == TaskFailureCode.staleRevision ||
          code == TaskFailureCode.notFound ||
          code == TaskFailureCode.deleted ||
          code == TaskFailureCode.undoExpired ||
          code == TaskFailureCode.undoReplaced;
      if (result.isSuccess || invalid) {
        _snapshot = null;
        _remaining = Duration.zero;
      }
      if (result.isSuccess) messageKey = 'taskRestored';
    }
    notifyListeners();
  }

  void dismissFeedback() {
    _snapshot = null;
    _remaining = Duration.zero;
    messageKey = null;
    failure = null;
    _sequence++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _snapshot = null;
    _remaining = Duration.zero;
    _undoPending = false;
    _pending.clear();
    _sequence++;
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}

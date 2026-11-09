import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/task_id.dart';

enum TodayFilter { all, solo, shared }

class TodayState {
  TodayState({
    List<TaskAggregate> entries = const [],
    this.isLoading = true,
    this.failure,
    this.filter = TodayFilter.all,
    Map<TaskId, int> streaks = const {},
  }) : entries = List.unmodifiable(entries),
       streaks = Map.unmodifiable(streaks);
  final List<TaskAggregate> entries;
  final bool isLoading;
  final TaskFailure? failure;
  final TodayFilter filter;
  final Map<TaskId, int> streaks;
}

class TodayViewModel extends ChangeNotifier {
  TodayViewModel({
    required this.clock,
    required Future<TaskResult<List<TaskAggregate>>> Function(LocalDateRange)
    load,
    Stream<TaskChange>? changes,
    this._loadStreaks,
  }) : _loadRange = load {
    _subscription = changes?.listen((_) => unawaited(this.load()));
    _scheduleMidnight();
  }

  final DateTime Function() clock;
  final Future<TaskResult<List<TaskAggregate>>> Function(LocalDateRange)
  _loadRange;
  final Future<TaskResult<Map<TaskId, int>>> Function(Set<TaskId>, LocalDate)?
  _loadStreaks;
  StreamSubscription<TaskChange>? _subscription;
  Timer? _midnight;
  TodayState _state = TodayState();
  TodayState get state => _state;
  LocalDate? _loadedDay;
  int _sequence = 0;
  bool _disposed = false;

  LocalDate get today {
    final now = clock().toLocal();
    return LocalDate(now.year, now.month, now.day);
  }

  List<TaskAggregate> get visible => _state.entries
      .where(
        (a) => switch (_state.filter) {
          TodayFilter.all => true,
          TodayFilter.solo => a.task.participants.isEmpty,
          TodayFilter.shared => a.task.participants.isNotEmpty,
        },
      )
      .toList(growable: false);
  int get pendingCount => visible.where((a) => !a.occurrence.completed).length;
  int get doneCount => visible.where((a) => a.occurrence.completed).length;

  void setFilter(TodayFilter filter) {
    _state = TodayState(
      entries: _state.entries,
      isLoading: _state.isLoading,
      failure: _state.failure,
      filter: filter,
      streaks: _state.streaks,
    );
    notifyListeners();
  }

  Future<void> load() async {
    if (_disposed) return;
    final sequence = ++_sequence;
    final date = today;
    _state = TodayState(
      entries: _state.entries,
      filter: _state.filter,
      streaks: _state.streaks,
    );
    notifyListeners();
    TaskResult<List<TaskAggregate>> result;
    try {
      result = await _loadRange(LocalDateRange(date, date));
    } catch (_) {
      result = TaskError(TaskFailure(TaskFailureCode.storageUnavailable));
    }
    if (_disposed || sequence != _sequence) return;
    final entries = result.value ?? <TaskAggregate>[];
    var failure = result.failure;
    var streaks = <TaskId, int>{};
    if (failure == null && _loadStreaks != null) {
      TaskResult<Map<TaskId, int>> history;
      try {
        history = await _loadStreaks(
          entries.map((a) => a.task.id).toSet(),
          date,
        );
      } catch (_) {
        history = TaskError(TaskFailure(TaskFailureCode.storageUnavailable));
      }
      if (_disposed || sequence != _sequence) return;
      streaks = history.value ?? {};
      failure = history.failure;
    }
    _loadedDay = date;
    _state = TodayState(
      entries: failure == null ? entries : const [],
      isLoading: false,
      failure: failure,
      filter: _state.filter,
      streaks: streaks,
    );
    notifyListeners();
  }

  void refreshForLocalDay() {
    if (_loadedDay != today) unawaited(load());
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    if (_disposed) return;
    final now = clock().toLocal();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(midnight.difference(now), refreshForLocalDay);
  }

  @override
  void dispose() {
    _disposed = true;
    _midnight?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

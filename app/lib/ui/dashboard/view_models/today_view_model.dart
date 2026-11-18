import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:app/domain/models/daily_overview.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/use_cases/build_daily_overview.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/task_id.dart';

enum TodayFilter { all, solo, shared }

class TodayState {
  TodayState({
    required this.now,
    List<TaskAggregate> entries = const [],
    this.isLoading = true,
    this.failure,
    this.scope = const DailyTaskScope.all(),
    this.overview,
    Map<TaskId, int> streaks = const {},
  }) : entries = List.unmodifiable(entries),
       streaks = Map.unmodifiable(streaks);
  final DateTime now;
  final List<TaskAggregate> entries;
  final bool isLoading;
  final TaskFailure? failure;
  final DailyTaskScope scope;
  final DailyOverview? overview;
  final Map<TaskId, int> streaks;
  TodayFilter get filter => switch (scope.kind) {
    DailyScopeKind.solo => TodayFilter.solo,
    DailyScopeKind.shared => TodayFilter.shared,
    _ => TodayFilter.all,
  };
}

class TodayViewModel extends ChangeNotifier {
  TodayViewModel({
    required this.clock,
    required Future<TaskResult<List<TaskAggregate>>> Function(LocalDateRange)
    load,
    Stream<TaskChange>? changes,
    Future<TaskResult<Map<TaskId, int>>> Function(Set<TaskId>, LocalDate)?
    loadStreaks,
    BuildDailyOverview overview = const BuildDailyOverview(),
  }) : _loadRange = load,
       _loadStreaks = loadStreaks,
       _overview = overview {
    _state = TodayState(now: clock().toLocal());
    _subscription = changes?.listen((_) => unawaited(this.load()));
    _scheduleMinute();
  }

  final DateTime Function() clock;
  final Future<TaskResult<List<TaskAggregate>>> Function(LocalDateRange)
  _loadRange;
  final Future<TaskResult<Map<TaskId, int>>> Function(Set<TaskId>, LocalDate)?
  _loadStreaks;
  final BuildDailyOverview _overview;
  StreamSubscription<TaskChange>? _subscription;
  Timer? _minuteTimer;
  late TodayState _state;
  TodayState get state => _state;
  LocalDate? _loadedDay, _loadingDay;
  int _sequence = 0;
  bool _disposed = false, _resumed = true;

  LocalDate get today {
    final local = clock().toLocal();
    return LocalDate(local.year, local.month, local.day);
  }

  List<TaskAggregate> get visible => _state.overview?.entries ?? const [];
  int get pendingCount => _state.overview?.progress.pending ?? 0;
  int get doneCount => _state.overview?.progress.completed ?? 0;

  void setFilter(TodayFilter filter) => setScope(switch (filter) {
    TodayFilter.all => const DailyTaskScope.all(),
    TodayFilter.solo => const DailyTaskScope.solo(),
    TodayFilter.shared => const DailyTaskScope.shared(),
  });

  void setScope(DailyTaskScope scope) {
    if (_disposed) return;
    _publish(scope: scope);
  }

  void _publish({DailyTaskScope? scope}) {
    final now = clock().toLocal();
    final requested = scope ?? _state.scope;
    final data =
        !_state.isLoading && _state.failure == null && _loadedDay == today
        ? _overview.execute(entries: _state.entries, now: now, scope: requested)
        : null;
    _state = TodayState(
      now: now,
      entries: _state.entries,
      isLoading: _state.isLoading,
      failure: _state.failure,
      scope: data?.scope ?? requested,
      overview: data,
      streaks: _state.streaks,
    );
    notifyListeners();
  }

  Future<void> load() async {
    if (_disposed) return;
    final sequence = ++_sequence;
    final date = today;
    _loadingDay = date;
    _state = TodayState(
      now: clock().toLocal(),
      entries: _state.entries,
      scope: _state.scope,
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
    if (date != today) return load();
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
      if (date != today) return load();
      streaks = history.value ?? {};
      failure = history.failure;
    }
    _loadedDay = date;
    _loadingDay = null;
    _state = TodayState(
      now: clock().toLocal(),
      entries: failure == null ? entries : const [],
      isLoading: false,
      failure: failure,
      scope: _state.scope,
      streaks: streaks,
    );
    _publish();
  }

  void refreshForClock() {
    if (_disposed) return;
    if (_loadedDay != today && _loadingDay != today) {
      unawaited(load());
    } else {
      _publish();
    }
    _scheduleMinute();
  }

  void refreshForLocalDay() => refreshForClock();

  void setResumed(bool resumed) {
    if (_disposed) return;
    _resumed = resumed;
    if (resumed) {
      refreshForClock();
    } else {
      _minuteTimer?.cancel();
    }
  }

  void _scheduleMinute() {
    _minuteTimer?.cancel();
    if (_disposed || !_resumed) return;
    final now = clock().toLocal();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _minuteTimer = Timer(next.difference(now), refreshForClock);
  }

  @override
  void dispose() {
    _disposed = true;
    _minuteTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

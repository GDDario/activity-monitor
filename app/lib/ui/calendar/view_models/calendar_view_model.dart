import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:app/domain/models/calendar_data.dart';
import 'package:app/ui/calendar/view_models/calendar_state.dart';

class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel(
    DateTime today,
    this._loadData, {
    this.reloadOnNavigation = false,
    this._loadStreaks,
  }) : calendar = CalendarState(today);

  final CalendarState calendar;
  final Future<CalendarData> Function() _loadData;
  final bool reloadOnNavigation;
  final Future<Map<String, int>> Function(CalendarData)? _loadStreaks;
  Map<String, int> streaks = const {};
  bool isLoading = true;
  bool hasError = false;
  bool _disposed = false;
  int _loadSequence = 0;

  Future<void> load() async {
    if (_disposed) return;
    final sequence = ++_loadSequence;
    isLoading = true;
    hasError = false;
    notifyListeners();
    try {
      final data = await _loadData();
      if (_disposed || sequence != _loadSequence) return;
      final counts = await _loadStreaks?.call(data) ?? const <String, int>{};
      if (_disposed || sequence != _loadSequence) return;
      calendar.data = data;
      streaks = Map.unmodifiable(counts);
      hasError = false;
    } catch (error) {
      if (_disposed || sequence != _loadSequence) return;
      debugPrint('Calendar data loading failed (${error.runtimeType}).');
      calendar.data = null;
      streaks = const {};
      hasError = true;
    }
    isLoading = false;
    notifyListeners();
  }

  void selectDate(DateTime date) {
    calendar.selected = DateTime(date.year, date.month, date.day);
    notifyListeners();
    if (reloadOnNavigation) unawaited(load());
  }

  void move(int amount) {
    calendar.move(amount);
    notifyListeners();
    if (reloadOnNavigation) unawaited(load());
  }

  void setWeekMode(bool value) {
    calendar.weekMode = value;
    notifyListeners();
    if (reloadOnNavigation) unawaited(load());
  }

  void setCadence(CalendarCadence? value) {
    calendar.cadence = value;
    notifyListeners();
  }

  void toggleParticipant(String id) {
    calendar.participantId = calendar.participantId == id ? null : id;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

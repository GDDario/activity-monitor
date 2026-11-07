import 'package:flutter/foundation.dart';

import 'package:app/domain/models/calendar_data.dart';
import 'package:app/ui/calendar/view_models/calendar_state.dart';

class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel(DateTime today, this._loadData)
    : calendar = CalendarState(today);

  final CalendarState calendar;
  final Future<CalendarData> Function() _loadData;
  bool isLoading = true;
  bool hasError = false;
  bool _disposed = false;

  Future<void> load() async {
    try {
      final data = await _loadData();
      if (_disposed) return;
      calendar.data = data;
      hasError = false;
    } catch (error) {
      if (_disposed) return;
      debugPrint('Calendar data loading failed (${error.runtimeType}).');
      calendar.data = null;
      hasError = true;
    }
    isLoading = false;
    notifyListeners();
  }

  void selectDate(DateTime date) {
    calendar.selected = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void move(int amount) {
    calendar.move(amount);
    notifyListeners();
  }

  void setWeekMode(bool value) {
    calendar.weekMode = value;
    notifyListeners();
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

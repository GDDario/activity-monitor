import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:app/domain/models/task_reminder.dart';

typedef RefreshReminders = Future<ReminderSnapshot> Function({
  bool request,
  bool timing,
});

class NotificationViewModel extends ChangeNotifier {
  NotificationViewModel({required this._refresh, required this._setEnabled});
  final RefreshReminders _refresh;
  final Future<void> Function(bool) _setEnabled;
  ReminderSnapshot? snapshot;
  bool _disposed = false,
      _again = false,
      _request = false,
      _timing = false,
      _changing = false;
  Future<void>? _running;
  bool get busy => _running != null || _changing;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh({bool request = false, bool timing = false}) {
    if (_disposed) return Future.value();
    _again = true;
    _request |= request;
    _timing |= timing;
    if (_running != null) return _running!;
    final done = Completer<void>();
    _running = done.future;
    _notify();
    unawaited(_drain(done));
    return done.future;
  }

  Future<void> _drain(Completer<void> done) async {
    while (_again && !_disposed) {
      _again = false;
      final request = _request, timing = _timing;
      _request = false;
      _timing = false;
      try {
        final value = await _refresh(request: request, timing: timing);
        if (!_disposed) snapshot = value;
      } catch (_) {
        if (!_disposed) {
          snapshot = ReminderSnapshot(
            enabled: snapshot?.enabled ?? false,
            availability: ReminderAvailability.unavailable,
          );
        }
      }
    }
    _running = null;
    _notify();
    done.complete();
  }

  Future<void> enable(bool value) async {
    if (_changing || _disposed) return;
    _changing = true;
    _notify();
    try {
      await _running;
      if (_disposed) return;
      await _setEnabled(value);
      if (!_disposed) await refresh(request: value);
    } catch (_) {
      if (!_disposed) {
        snapshot = ReminderSnapshot(
          enabled: snapshot?.enabled ?? false,
          availability: ReminderAvailability.unavailable,
        );
      }
    } finally {
      _changing = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

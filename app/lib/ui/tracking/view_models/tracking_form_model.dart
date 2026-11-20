import 'package:flutter/foundation.dart';

import 'package:app/data/repositories/tracking_repository.dart';
import 'package:app/domain/models/task_tracking.dart';

class TrackingFormModel extends ChangeNotifier {
  TrackingFormModel({
    required this.type,
    required this.scope,
    Map<String, Object?> values = const {},
  }) : _values = trackingValues(values);
  final TaskType type;
  final FieldScope scope;
  Map<String, Object?> _values;
  Map<String, Object?> get values => _values;
  bool busy = false, dirty = false, showErrors = false, _disposed = false;
  String? failure;
  Map<String, String> serverErrors = {};
  Map<String, String> get errors => {
    ...type.validateValues(_values, scope),
    ...serverErrors,
  };
  bool get valid => errors.isEmpty;
  void set(String id, Object? value) {
    if (busy || _disposed) return;
    _values = trackingValues({..._values, id: value});
    dirty = true;
    serverErrors = {};
    failure = null;
    notifyListeners();
  }

  Future<bool> submit(Future<void> Function(Map<String, Object?>) save) async {
    if (busy || _disposed) return false;
    showErrors = true;
    if (!valid) {
      notifyListeners();
      return false;
    }
    busy = true;
    failure = null;
    notifyListeners();
    try {
      await save(_values);
      if (_disposed) return true;
      dirty = false;
      busy = false;
      notifyListeners();
      return true;
    } on TrackingFailure catch (e) {
      failure = e.code;
      serverErrors = e.fields;
    } catch (_) {
      failure = 'storageUnavailable';
    }
    if (_disposed) return false;
    busy = false;
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

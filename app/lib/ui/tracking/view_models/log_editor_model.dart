import 'package:app/domain/models/task_tracking.dart';
import 'package:app/ui/tracking/view_models/tracking_form_model.dart';
import 'package:app/ui/tracking/view_models/tracking_view_model.dart';

class LogEditorModel extends TrackingFormModel {
  LogEditorModel(this.owner, {this.original})
    : id = original?.id ?? owner.newId(),
      recordedAt = original?.recordedAt.toLocal() ?? owner.clock().toLocal(),
      super(
        type: original?.type ?? owner.detail!.setup.type,
        scope: FieldScope.log,
        values: original?.values ?? _initial(owner),
      );
  final TrackingViewModel owner;
  final ActivityLog? original;
  final String id;
  DateTime recordedAt;
  static Map<String, Object?> _initial(TrackingViewModel owner) {
    final detail = owner.detail!, timer = detail.timer;
    return {
      ...initialLogValues(detail.setup),
      if (timer != null &&
          timer.taskId == detail.id &&
          timer.stoppedSeconds != null)
        timer.fieldId: timer.stoppedSeconds,
    };
  }

  void changeDate(DateTime date) {
    if (busy) return;
    recordedAt = date;
    dirty = true;
    notifyListeners();
  }

  @override
  Map<String, String> get errors => {
    ...super.errors,
    if (recordedAt.isAfter(owner.clock())) 'recordedAt': 'invalid',
  };
  Future<bool> save() => submit((values) async {
    final timer = owner.detail!.timer;
    await owner.saveLog(
      ActivityLog(
        id: id,
        taskId: owner.detail!.id,
        recordedAt: recordedAt,
        type: type,
        values: values,
        revision: original?.revision ?? 0,
        occurrenceId: original?.occurrenceId,
      ),
      expected: original?.revision,
      timerRevision:
          original == null &&
              timer?.taskId == owner.detail!.id &&
              timer?.stoppedSeconds != null
          ? timer!.revision
          : null,
    );
  });
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/subtask_id.dart';
import 'package:app/domain/value_objects/tag_id.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/weekly_days.dart';

enum DraftDismissal { close, confirmDiscard, blocked }

class TaskEditorState {
  TaskEditorState({
    required this.draft,
    this.isSaving = false,
    this.isLoading = false,
    this.isLoadFailed = false,
    this.isDirty = false,
    this.hasSaved = false,
    this.showErrors = false,
    this.failure,
    this.overlaps,
    Map<String, String> fieldErrors = const {},
  }) : fieldErrors = Map.unmodifiable(fieldErrors);
  final TaskDraft draft;
  final bool isSaving, isLoading, isLoadFailed, isDirty, hasSaved, showErrors;
  final TaskFailure? failure;
  final bool? overlaps;
  final Map<String, String> fieldErrors;
}

class TaskEditorViewModel extends ChangeNotifier {
  TaskEditorViewModel({
    required TaskDraft draft,
    required this.newId,
    required Map<String, String> Function(TaskDraft) validate,
    required this._save,
    this._checkOverlap,
    this._load,
  }) : _validate = validate,
       _state = TaskEditorState(draft: draft, fieldErrors: validate(draft));

  final String Function() newId;
  final Map<String, String> Function(TaskDraft) _validate;
  final Future<TaskResult<TaskSaveResult>> Function(TaskDraft) _save;
  final Future<TaskResult<bool>> Function(TaskDraft)? _checkOverlap;
  final Future<TaskResult<TaskAggregate>> Function(TaskId, OccurrenceId)? _load;
  TaskEditorState _state;
  TaskEditorState get state => _state;
  final Map<String, String> _inputErrors = {};
  Timer? _advisoryTimer;
  int _advisorySequence = 0;
  int _loadSequence = 0;
  bool _disposed = false;

  bool get canEdit =>
      !_disposed &&
      !_state.isLoading &&
      !_state.isSaving &&
      !_state.isLoadFailed &&
      !_state.hasSaved;
  bool get canSave => canEdit && _state.fieldErrors.isEmpty;
  String? get firstInvalidField => _state.fieldErrors.keys.firstOrNull;

  void _set({
    TaskDraft? draft,
    bool? isSaving,
    bool? isLoading,
    bool? isLoadFailed,
    bool? dirty,
    bool? hasSaved,
    bool? showErrors,
    TaskFailure? failure,
    bool? overlaps,
    bool keepOverlap = true,
  }) {
    if (_disposed) return;
    final nextDraft = draft ?? _state.draft;
    _state = TaskEditorState(
      draft: nextDraft,
      isSaving: isSaving ?? _state.isSaving,
      isLoading: isLoading ?? _state.isLoading,
      isLoadFailed: isLoadFailed ?? _state.isLoadFailed,
      isDirty: dirty ?? _state.isDirty,
      hasSaved: hasSaved ?? _state.hasSaved,
      showErrors: showErrors ?? _state.showErrors,
      failure: failure,
      overlaps: keepOverlap ? (overlaps ?? _state.overlaps) : overlaps,
      fieldErrors: {..._validate(nextDraft), ..._inputErrors},
    );
    notifyListeners();
  }

  Future<void> loadExisting(TaskId taskId, OccurrenceId occurrenceId) async {
    final load = _load;
    if (load == null || _state.isSaving || _disposed) return;
    final sequence = ++_loadSequence;
    _advisoryTimer?.cancel();
    _advisorySequence++;
    _set(
      isLoading: true,
      isLoadFailed: false,
      hasSaved: false,
      dirty: false,
      keepOverlap: false,
    );
    TaskResult<TaskAggregate> result;
    try {
      result = await load(taskId, occurrenceId);
    } catch (_) {
      result = TaskError(TaskFailure(TaskFailureCode.storageUnavailable));
    }
    if (_disposed || sequence != _loadSequence) return;
    final aggregate = result.value;
    if (aggregate == null) {
      // A failed edit load must never become an independently writable create draft.
      _set(
        isLoading: false,
        isLoadFailed: true,
        dirty: false,
        failure: result.failure,
      );
      return;
    }
    _inputErrors.clear();
    _set(
      isLoading: false,
      isLoadFailed: false,
      draft: TaskDraft.fromAggregate(aggregate),
      dirty: false,
      hasSaved: false,
      keepOverlap: false,
    );
  }

  Future<TaskResult<bool>> _readAdvisory(TaskDraft draft) async {
    try {
      return await _checkOverlap!(draft);
    } catch (_) {
      return TaskError(TaskFailure(TaskFailureCode.storageUnavailable));
    }
  }

  void change(TaskDraft draft) {
    if (!canEdit) return;
    _set(draft: draft, dirty: true);
    if (_checkOverlap == null) return;
    _advisoryTimer?.cancel();
    final sequence = ++_advisorySequence;
    _advisoryTimer = Timer(const Duration(milliseconds: 250), () async {
      final result = await _readAdvisory(draft);
      if (!canEdit || sequence != _advisorySequence) return;
      _set(overlaps: result.value, keepOverlap: false, failure: result.failure);
    });
  }

  void setInputError(String field, String? error) {
    if (!canEdit) return;
    if (error == null) {
      _inputErrors.remove(field);
    } else {
      _inputErrors[field] = error;
    }
    _set(dirty: true, showErrors: true);
  }

  void setCadence(TaskCadence cadence) {
    if (!canEdit || cadence == _state.draft.cadence) return;
    final d = _state.draft;
    change(
      d.copyWith(
        cadence: cadence,
        recurrenceEnabled: cadence != TaskCadence.oneTime,
        weeklyDays: cadence == TaskCadence.weekly
            ? WeeklyDays(1 << (d.date.weekday - 1))
            : null,
        streakEnabled: cadence == TaskCadence.daily ? d.streakEnabled : false,
        dayPeriod: cadence == TaskCadence.daily ? d.dayPeriod : null,
      ),
    );
  }

  void addTag(String name) {
    if (!canEdit) return;
    change(
      _state.draft.copyWith(
        tags: [
          ..._state.draft.tags,
          DraftTag(id: TagId(newId()), name: name),
        ],
      ),
    );
  }

  void removeTag(int index) {
    if (!canEdit) return;
    final items = [..._state.draft.tags]..removeAt(index);
    change(_state.draft.copyWith(tags: items));
  }

  void addSubtask() {
    if (!canEdit) return;
    change(
      _state.draft.copyWith(
        subtasks: [
          ..._state.draft.subtasks,
          DraftSubtask(id: SubtaskId(newId()), title: ''),
        ],
      ),
    );
  }

  void changeSubtask(int index, {String? title, bool? completed}) {
    if (!canEdit) return;
    final items = [..._state.draft.subtasks];
    items[index] = items[index].copyWith(title: title, completed: completed);
    change(_state.draft.copyWith(subtasks: items));
  }

  void removeSubtask(int index) {
    if (!canEdit) return;
    final items = [..._state.draft.subtasks]..removeAt(index);
    change(_state.draft.copyWith(subtasks: items));
  }

  void moveSubtask(int index, int target) {
    if (!canEdit) return;
    final items = [..._state.draft.subtasks];
    if (target < 0 || target >= items.length) return;
    final item = items.removeAt(index);
    items.insert(target, item);
    change(_state.draft.copyWith(subtasks: items));
  }

  DraftDismissal requestDismissal() => _state.isSaving
      ? DraftDismissal.blocked
      : _state.isDirty
      ? DraftDismissal.confirmDiscard
      : DraftDismissal.close;

  Future<bool> save() async {
    if (!canEdit) {
      return false;
    }
    _advisoryTimer?.cancel();
    _advisorySequence++;
    if (!canSave) {
      _set(showErrors: true);
      return false;
    }
    final draft = _state.draft;
    _set(isSaving: true);
    TaskResult<TaskSaveResult> result;
    try {
      if (_checkOverlap != null) {
        final advisory = await _readAdvisory(draft);
        if (_disposed) {
          return false;
        }
        _set(overlaps: advisory.value, keepOverlap: false);
      }
      result = await _save(draft);
    } catch (_) {
      result = TaskError(TaskFailure(TaskFailureCode.storageUnavailable));
    }
    if (_disposed) {
      return false;
    }
    _set(
      isSaving: false,
      hasSaved: result.isSuccess,
      dirty: result.isSuccess ? false : null,
      failure: result.failure,
      showErrors: result.failure?.code == TaskFailureCode.validation,
    );
    return result.isSuccess;
  }

  @override
  void dispose() {
    _disposed = true;
    _loadSequence++;
    _advisorySequence++;
    _advisoryTimer?.cancel();
    super.dispose();
  }
}

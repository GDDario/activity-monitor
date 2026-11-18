import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:app/data/repositories/people_repository.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/domain/use_cases/build_people_directory.dart';
import 'package:app/domain/value_objects/local_date.dart';

class PeopleState {
  const PeopleState({
    this.snapshot,
    this.loading = false,
    this.failure,
    this.query = '',
    this.filter = 'all',
  });
  final PeopleSnapshot? snapshot;
  final bool loading;
  final PeopleFailure? failure;
  final String query, filter;
}

class PeopleViewModel extends ChangeNotifier {
  PeopleViewModel(this.repository, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now {
    _subscription = repository.changes.listen((_) => unawaited(load()));
  }
  final PeopleRepository repository;
  final DateTime Function() clock;
  PeopleState _state = const PeopleState();
  PeopleState get state => _state;
  StreamSubscription<String>? _subscription;
  Timer? _timer;
  int _sequence = 0;
  bool _disposed = false, _resumed = true;
  LocalDate get today {
    final d = clock().toLocal();
    return LocalDate(d.year, d.month, d.day);
  }

  List<Person> visible({Map<String, String> labels = const {}}) =>
      BuildPeopleDirectory().execute(
        _state.snapshot ?? PeopleSnapshot(),
        query: _state.query,
        filter: _state.filter,
        labels: labels,
      );
  void _emit(PeopleState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  void setQuery(String query) => _emit(
    PeopleState(
      snapshot: state.snapshot,
      loading: state.loading,
      failure: state.failure,
      query: query,
      filter: state.filter,
    ),
  );
  void setFilter(String filter) => _emit(
    PeopleState(
      snapshot: state.snapshot,
      loading: state.loading,
      failure: state.failure,
      query: state.query,
      filter: filter,
    ),
  );
  Future<void> load() async {
    if (_disposed) return;
    final seq = ++_sequence, day = today;
    _emit(
      PeopleState(
        snapshot: state.snapshot,
        loading: true,
        query: state.query,
        filter: state.filter,
      ),
    );
    PeopleResult<PeopleSnapshot> result;
    try {
      result = await repository.loadSnapshot(day);
    } catch (_) {
      result = const PeopleResult.error(PeopleFailure.storageUnavailable);
    }
    if (_disposed || seq != _sequence) return;
    if (day != today) {
      unawaited(load());
      return;
    }
    _emit(
      PeopleState(
        snapshot: result.value ?? state.snapshot,
        failure: result.failure,
        query: state.query,
        filter: state.filter,
      ),
    );
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    if (_disposed || !_resumed) return;
    final now = clock().toLocal();
    _timer = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () => unawaited(load()),
    );
  }

  void setResumed(bool resumed) {
    _resumed = resumed;
    _timer?.cancel();
    if (resumed) unawaited(load());
  }

  @override
  void dispose() {
    _disposed = true;
    _sequence++;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

class PersonEditorState {
  const PersonEditorState({
    required this.draft,
    this.saving = false,
    this.saved = false,
    this.showErrors = false,
    this.dirty = false,
    this.failure,
  });
  final PersonDraft draft;
  final bool saving, saved, showErrors, dirty;
  final PeopleFailure? failure;
}

class PersonEditorViewModel extends ChangeNotifier {
  PersonEditorViewModel(this.repository, PersonDraft draft)
    : _state = PersonEditorState(draft: draft);
  final PeopleRepository repository;
  PersonEditorState _state;
  PersonEditorState get state => _state;
  bool _disposed = false;
  void change({String? name, String? role, Set<PersonCategory>? categories}) {
    if (state.saving || state.saved || _disposed) return;
    final d = state.draft;
    _state = PersonEditorState(
      draft: PersonDraft(
        id: d.id,
        name: name ?? d.name,
        role: role ?? d.role,
        categories: categories ?? d.categories,
        expectedRevision: d.expectedRevision,
      ),
      dirty: true,
      showErrors: state.showErrors,
    );
    notifyListeners();
  }

  Future<bool> save() async {
    if (state.saving || state.saved || _disposed) return false;
    if (state.draft.errors.isNotEmpty) {
      _state = PersonEditorState(
        draft: state.draft,
        dirty: state.dirty,
        showErrors: true,
      );
      notifyListeners();
      return false;
    }
    _state = PersonEditorState(
      draft: state.draft,
      saving: true,
      dirty: state.dirty,
    );
    notifyListeners();
    PeopleResult<Person> result;
    try {
      result = await repository.savePerson(state.draft);
    } catch (_) {
      result = const PeopleResult.error(PeopleFailure.storageUnavailable);
    }
    if (_disposed) return false;
    _state = PersonEditorState(
      draft: state.draft,
      saved: result.isSuccess,
      dirty: !result.isSuccess,
      failure: result.failure,
    );
    notifyListeners();
    return result.isSuccess;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class PersonDetailState {
  const PersonDetailState({
    this.activities,
    this.loading = false,
    this.failure,
    this.ascending = false,
  });
  final PersonActivityPage? activities;
  final bool loading, ascending;
  final PeopleFailure? failure;
}

class PersonDetailViewModel extends ChangeNotifier {
  PersonDetailViewModel(this.repository, this.personId);
  final PeopleRepository repository;
  final String personId;
  PersonDetailState _state = const PersonDetailState();
  PersonDetailState get state => _state;
  bool _disposed = false;
  int _sequence = 0;
  Future<void> load({int? page, bool? ascending}) async {
    if (_disposed) return;
    final seq = ++_sequence, order = ascending ?? state.ascending;
    final index = ascending != null ? 0 : page ?? state.activities?.page ?? 0;
    _state = PersonDetailState(
      activities: state.activities,
      loading: true,
      ascending: order,
    );
    notifyListeners();
    PeopleResult<PersonActivityPage> result;
    try {
      result = await repository.loadPersonActivities(
        personId,
        page: index,
        ascending: order,
      );
    } catch (_) {
      result = const PeopleResult.error(PeopleFailure.storageUnavailable);
    }
    if (_disposed || seq != _sequence) return;
    _state = PersonDetailState(
      activities: result.value ?? state.activities,
      failure: result.failure,
      ascending: order,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sequence++;
    super.dispose();
  }
}

import 'dart:async';
import 'dart:developer' as developer;

import 'package:app/data/services/people_database.dart';
import 'package:app/data/services/task_row_mapper.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/domain/value_objects/local_date.dart';

abstract class PeopleRepository {
  Stream<String> get changes;
  Future<PeopleResult<PeopleSnapshot>> loadSnapshot(LocalDate today);
  Future<PeopleResult<PersonActivityPage>> loadPersonActivities(
    String id, {
    int page = 0,
    bool ascending = false,
  });
  Future<PeopleResult<Person>> savePerson(PersonDraft draft);
  Future<void> dispose();
}

class LocalPeopleRepository implements PeopleRepository {
  LocalPeopleRepository(this.database);
  final PeopleDatabase database;
  final _changes = StreamController<String>.broadcast();
  @override
  Stream<String> get changes => _changes.stream;
  Future<PeopleResult<T>> _run<T>(
    Map<String, Object?> request,
    T Function(Map<String, Object?>) map,
  ) async {
    try {
      final r = await database.request(request);
      if (r['failure'] != null) {
        final failure = PeopleFailure.values.byName(r['failure'] as String);
        if (failure == PeopleFailure.storageUnavailable) {
          developer.log(
            'People storage unavailable',
            name: 'people_repository',
            error: request['operation'],
          );
        }
        return PeopleResult.error(failure);
      }
      return PeopleResult.success(map(r));
    } catch (e) {
      developer.log(
        'People operation failed',
        name: 'people_repository',
        error: e.runtimeType,
      );
      return const PeopleResult.error(PeopleFailure.storageUnavailable);
    }
  }

  List<Map<String, Object?>> _rows(Map<String, Object?> r, String key) =>
      (r[key] as List).map((e) => Map<String, Object?>.from(e as Map)).toList();
  @override
  Future<PeopleResult<PeopleSnapshot>> loadSnapshot(LocalDate today) => _run(
    {
      'operation': 'snapshot',
      'today': today.toString(),
      'since': today.addDays(-29).toString(),
    },
    (r) {
      final categories = _rows(r, 'categories'),
          stats = _rows(r, 'stats'),
          last = _rows(r, 'last');
      final people = _rows(r, 'people')
          .map(
            (p) => Person(
              id: p['id'] as String,
              name: p['name'] as String,
              role: p['role'] as String? ?? '',
              revision: p['revision'] as int,
              categories: categories
                  .where((c) => c['participant_id'] == p['id'])
                  .map(
                    (c) =>
                        PersonCategory.values.byName(c['category'] as String),
                  )
                  .toSet(),
            ),
          )
          .toList();
      return PeopleSnapshot(
        people: people,
        solo: r['solo'] as int,
        shared: r['shared'] as int,
        activeShared: r['active'] as int,
        stats: {
          for (final p in people)
            p.id: () {
              final s = stats
                  .where((s) => s['participant_id'] == p.id)
                  .firstOrNull;
              final l = last
                  .where((l) => l['participant_id'] == p.id)
                  .firstOrNull;
              return PersonStats(
                active: s?['active'] as int? ?? 0,
                recent: s?['recent'] as int? ?? 0,
                lastTitle: l?['title'] as String?,
                lastDate: l?['effective_date'] as String?,
              );
            }(),
        },
      );
    },
  );
  @override
  Future<PeopleResult<PersonActivityPage>> loadPersonActivities(
    String id, {
    int page = 0,
    bool ascending = false,
  }) => _run(
    {'operation': 'history', 'id': id, 'page': page, 'ascending': ascending},
    (r) => PersonActivityPage(
      entries: _rows(r, 'rows').map(taskAggregateFromRow).toList(),
      total: r['total'] as int,
      page: r['page'] as int,
    ),
  );
  @override
  Future<PeopleResult<Person>> savePerson(PersonDraft draft) async {
    if (draft.errors.isNotEmpty) {
      return const PeopleResult.error(PeopleFailure.validation);
    }
    final result = await _run(
      {
        'operation': 'save',
        'id': draft.id,
        'name': draft.name.trim(),
        'role': draft.role.trim(),
        'categories': draft.categories.map((c) => c.name).toList(),
        'expected': draft.expectedRevision,
      },
      (r) => Person(
        id: draft.id,
        name: draft.name.trim(),
        role: draft.role.trim(),
        categories: draft.categories,
        revision: r['revision'] as int,
      ),
    );
    if (result.isSuccess && !_changes.isClosed) _changes.add(draft.id);
    return result;
  }

  @override
  Future<void> dispose() => _changes.close();
}

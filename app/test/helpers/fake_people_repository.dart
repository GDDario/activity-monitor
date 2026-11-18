import 'dart:async';

import 'package:app/data/repositories/people_repository.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/domain/value_objects/local_date.dart';

class FakePeopleRepository implements PeopleRepository {
  FakePeopleRepository(this.snapshot);
  PeopleSnapshot snapshot;
  PeopleFailure? failure;
  final events = StreamController<String>.broadcast();
  @override
  Stream<String> get changes => events.stream;
  @override
  Future<PeopleResult<PeopleSnapshot>> loadSnapshot(LocalDate today) async =>
      failure == null
      ? PeopleResult.success(snapshot)
      : PeopleResult.error(failure);
  @override
  Future<PeopleResult<PersonActivityPage>> loadPersonActivities(
    String id, {
    int page = 0,
    bool ascending = false,
  }) async =>
      PeopleResult.success(PersonActivityPage(entries: [], total: 0, page: 0));
  @override
  Future<PeopleResult<Person>> savePerson(PersonDraft d) async {
    final p = Person(
      id: d.id,
      name: d.name.trim(),
      role: d.role.trim(),
      categories: d.categories,
      revision: (d.expectedRevision ?? -1) + 1,
    );
    snapshot = PeopleSnapshot(
      people: [...snapshot.people.where((e) => e.id != p.id), p],
      stats: snapshot.stats,
      solo: snapshot.solo,
      shared: snapshot.shared,
      activeShared: snapshot.activeShared,
    );
    events.add(p.id);
    return PeopleResult.success(p);
  }

  @override
  Future<void> dispose() => events.close();
}

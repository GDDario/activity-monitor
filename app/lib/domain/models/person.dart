import 'package:app/domain/models/task.dart';

enum PersonCategory { work, household, creative, family }

class Person {
  Person({
    required this.id,
    required this.name,
    this.role = '',
    Set<PersonCategory> categories = const {},
    this.revision = 0,
  }) : categories = Set.unmodifiable(categories);
  final String id, name, role;
  final Set<PersonCategory> categories;
  final int revision;
}

class PersonDraft {
  PersonDraft({
    required this.id,
    required this.name,
    this.role = '',
    Set<PersonCategory> categories = const {},
    this.expectedRevision,
  }) : categories = Set.unmodifiable(categories);
  factory PersonDraft.fromPerson(Person p) => PersonDraft(
    id: p.id,
    name: p.name,
    role: p.role,
    categories: p.categories,
    expectedRevision: p.revision,
  );
  final String id, name, role;
  final Set<PersonCategory> categories;
  final int? expectedRevision;
  Map<String, String> get errors => {
    if (id.trim().isEmpty) 'id': 'invalid',
    if (name.trim().isEmpty || name.trim().runes.length > 100)
      'name': 'invalid',
    if (role.trim().runes.length > 100) 'role': 'invalid',
  };
}

class PersonStats {
  const PersonStats({
    this.active = 0,
    this.recent = 0,
    this.lastTitle,
    this.lastDate,
  });
  final int active, recent;
  final String? lastTitle, lastDate;
}

class PeopleSnapshot {
  PeopleSnapshot({
    List<Person> people = const [],
    Map<String, PersonStats> stats = const {},
    this.solo = 0,
    this.shared = 0,
    this.activeShared = 0,
  }) : people = List.unmodifiable(people),
       stats = Map.unmodifiable(stats);
  final List<Person> people;
  final Map<String, PersonStats> stats;
  final int solo, shared, activeShared;
  int get total => solo + shared;
  int get sharedPercent => total == 0 ? 0 : (shared / total * 100).round();
  int get soloPercent => total == 0 ? 0 : 100 - sharedPercent;
}

class PersonActivityPage {
  PersonActivityPage({
    required List<TaskAggregate> entries,
    required this.total,
    required this.page,
  }) : entries = List.unmodifiable(entries);
  final List<TaskAggregate> entries;
  final int total, page;
  int get pages => total == 0 ? 1 : (total / 20).ceil();
}

enum PeopleFailure {
  validation,
  notFound,
  staleRevision,
  identityConflict,
  storageUnavailable,
}

class PeopleResult<T> {
  const PeopleResult.success(this.value) : failure = null;
  const PeopleResult.error(this.failure) : value = null;
  final T? value;
  final PeopleFailure? failure;
  bool get isSuccess => failure == null;
}

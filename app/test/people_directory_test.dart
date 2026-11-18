import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/domain/use_cases/build_people_directory.dart';

void main() {
  test('person draft rejects blank and overlong input with scalar limits', () {
    expect(PersonDraft(id: 'a', name: '   ').errors, contains('name'));
    expect(PersonDraft(id: 'a', name: '😀' * 101).errors, contains('name'));
    expect(PersonDraft(id: 'a', name: '😀' * 100).errors, isEmpty);
    expect(
      PersonDraft(id: 'a', name: 'Ana', role: 'r' * 101).errors,
      contains('role'),
    );
  });
  test('accent search and category combine without changing global counts', () {
    final snapshot = PeopleSnapshot(
      people: [
        Person(
          id: 'a',
          name: 'Ána',
          role: 'Designer',
          categories: {PersonCategory.work},
        ),
        Person(id: 'b', name: 'Ana', categories: {PersonCategory.family}),
      ],
      stats: {'a': const PersonStats(recent: 3)},
      solo: 1,
      shared: 2,
      activeShared: 1,
    );
    final result = BuildPeopleDirectory().execute(
      snapshot,
      query: ' ANA ',
      filter: 'work',
    );
    expect(result.map((p) => p.id), ['a']);
    expect(
      BuildPeopleDirectory()
          .execute(snapshot, filter: 'frequent')
          .map((p) => p.id),
      ['a'],
    );
    expect(snapshot.sharedPercent, 67);
    expect(snapshot.soloPercent, 33);
    expect(snapshot.people.length, 2);
  });
  test(
    'search matches localized categories and roles with stable name ties',
    () {
      final snapshot = PeopleSnapshot(
        people: [
          Person(id: 'b', name: 'Sam', categories: {PersonCategory.work}),
          Person(id: 'a', name: 'Sam', role: 'Ártist'),
        ],
      );
      expect(
        BuildPeopleDirectory().execute(snapshot, query: 'artist').single.id,
        'a',
      );
      expect(
        BuildPeopleDirectory()
            .execute(snapshot, query: 'trabalho', labels: {'work': 'Trabalho'})
            .single
            .id,
        'b',
      );
      expect(BuildPeopleDirectory().execute(snapshot).map((e) => e.id), [
        'a',
        'b',
      ]);
      expect(snapshot.sharedPercent, 0);
    },
  );
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/data/repositories/people_repository.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/ui/people/view_models/people_view_model.dart';

class FakePeople extends PeopleRepository {
  final pending = <Completer<PeopleResult<PeopleSnapshot>>>[];
  PeopleResult<Person> saveResult = const PeopleResult.error(
    PeopleFailure.storageUnavailable,
  );
  int saves = 0;
  @override
  Stream<String> get changes => const Stream.empty();
  @override
  Future<PeopleResult<PeopleSnapshot>> loadSnapshot(LocalDate today) {
    final c = Completer<PeopleResult<PeopleSnapshot>>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<PeopleResult<PersonActivityPage>> loadPersonActivities(
    String id, {
    int page = 0,
    bool ascending = false,
  }) async =>
      PeopleResult.success(PersonActivityPage(entries: [], total: 0, page: 0));
  @override
  Future<PeopleResult<Person>> savePerson(PersonDraft draft) async {
    saves++;
    return saveResult;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('newer refresh wins and search/filter survive refresh', () async {
    final repo = FakePeople();
    final vm = PeopleViewModel(repo, clock: () => DateTime(2026, 11, 18));
    addTearDown(vm.dispose);
    vm.setQuery('ana');
    vm.setFilter('work');
    final first = vm.load();
    final second = vm.load();
    repo.pending[1].complete(
      PeopleResult.success(
        PeopleSnapshot(
          people: [
            Person(id: 'new', name: 'Ana', categories: {PersonCategory.work}),
          ],
        ),
      ),
    );
    await second;
    repo.pending[0].complete(
      PeopleResult.success(
        PeopleSnapshot(
          people: [Person(id: 'old', name: 'Ana')],
        ),
      ),
    );
    await first;
    expect(vm.visible().single.id, 'new');
    expect(vm.state.query, 'ana');
    expect(vm.state.filter, 'work');
  });
  test(
    'a read crossing midnight reloads current day and resume refreshes',
    () async {
      final repo = FakePeople();
      var now = DateTime(2026, 11, 18, 23, 59);
      final vm = PeopleViewModel(repo, clock: () => now);
      addTearDown(vm.dispose);
      final old = vm.load();
      now = DateTime(2026, 11, 19, 0, 1);
      repo.pending[0].complete(
        PeopleResult.success(
          PeopleSnapshot(
            people: [Person(id: 'old', name: 'Yesterday')],
          ),
        ),
      );
      await old;
      expect(repo.pending.length, 2);
      expect(vm.state.loading, true);
      repo.pending[1].complete(
        PeopleResult.success(
          PeopleSnapshot(
            people: [Person(id: 'new', name: 'Today')],
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(vm.visible().single.id, 'new');
      vm.setResumed(false);
      now = DateTime(2026, 11, 20);
      vm.setResumed(true);
      expect(repo.pending.length, 3);
      repo.pending[2].complete(PeopleResult.success(PeopleSnapshot()));
      await Future<void>.delayed(Duration.zero);
      expect(vm.visible(), isEmpty);
    },
  );
  test('editor retains failed draft and rejects invalid save', () async {
    final repo = FakePeople();
    final vm = PersonEditorViewModel(repo, PersonDraft(id: 'p', name: ''));
    addTearDown(vm.dispose);
    expect(await vm.save(), false);
    expect(repo.saves, 0);
    vm.change(name: 'Ana');
    expect(await vm.save(), false);
    expect(vm.state.draft.name, 'Ana');
    expect(vm.state.failure, PeopleFailure.storageUnavailable);
    repo.saveResult = PeopleResult.success(Person(id: 'p', name: 'Ana'));
    expect(await vm.save(), true);
    expect(vm.state.saved, true);
  });
}

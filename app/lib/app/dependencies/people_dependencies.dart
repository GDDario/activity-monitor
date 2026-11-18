import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/people_repository_dependencies.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/ui/people/view_models/people_view_model.dart';

final peopleViewModelProvider = FutureProvider<PeopleViewModel>((ref) async {
  final repository = await ref.watch(peopleRepositoryProvider.future);
  final model = PeopleViewModel(repository, clock: ref.read(taskClockProvider));
  final lifecycle = AppLifecycleListener(
    onStateChange: (state) =>
        model.setResumed(state == AppLifecycleState.resumed),
  );
  ref.listen(
    taskChangesProvider,
    (_, change) => change.whenData((_) => unawaited(model.load())),
  );
  ref.onDispose(() {
    lifecycle.dispose();
    model.dispose();
  });
  unawaited(model.load());
  return model;
});
final personEditorFactoryProvider =
    Provider<Future<PersonEditorViewModel> Function(Person?)>(
      (ref) =>
          (person) async => PersonEditorViewModel(
            await ref.read(peopleRepositoryProvider.future),
            person == null
                ? PersonDraft(id: ref.read(taskIdGeneratorProvider)(), name: '')
                : PersonDraft.fromPerson(person),
          ),
    );
final personDetailFactoryProvider =
    Provider<Future<PersonDetailViewModel> Function(String)>(
      (ref) =>
          (id) async => PersonDetailViewModel(
            await ref.read(peopleRepositoryProvider.future),
            id,
          ),
    );

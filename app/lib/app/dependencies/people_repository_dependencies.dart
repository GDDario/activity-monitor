import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/database_dependencies.dart';
import 'package:app/data/repositories/people_repository.dart';
import 'package:app/data/services/people_database.dart';

final peopleRepositoryProvider = FutureProvider<PeopleRepository>((ref) async {
  final path = await ref.watch(databaseInitializationProvider.future);
  final repository = LocalPeopleRepository(PeopleDatabase(path: path));
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});
final peopleChangesProvider = StreamProvider<String>((ref) async* {
  final repo = await ref.watch(peopleRepositoryProvider.future);
  yield* repo.changes;
});

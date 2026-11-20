import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app/dependencies/database_dependencies.dart';
import 'package:app/data/repositories/tracking_repository.dart';
import 'package:app/data/services/tracking_database.dart';
import 'package:app/ui/tracking/view_models/tracking_view_model.dart';

final trackingRepositoryProvider = FutureProvider<TrackingRepository>((
  ref,
) async {
  final path = await ref.watch(databaseInitializationProvider.future);
  final repository = TrackingRepository(TrackingDatabase(path));
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});
final trackingFactoryProvider = Provider<Future<TrackingViewModel> Function()>(
  (ref) =>
      () async => TrackingViewModel(
        await ref.read(trackingRepositoryProvider.future),
        newId: ref.read(uuidProvider).v7,
        clock: DateTime.now,
      ),
);

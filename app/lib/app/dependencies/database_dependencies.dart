import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:app/data/services/database/app_database.dart';

final uuidProvider = Provider<Uuid>((ref) => const Uuid());
final databaseDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getApplicationSupportDirectory,
);
final databaseInitializationProvider = FutureProvider<String>((ref) async {
  try {
    final directory = await ref.watch(databaseDirectoryProvider)();
    await Directory(directory.path).create(recursive: true);
    final path = '${directory.path}/activity_monitor.db';
    await compute(initializeDatabaseAtPath, path);
    return path;
  } catch (error) {
    debugPrint(
      'Database initialization failed (${error.runtimeType}); task data is unavailable.',
    );
    rethrow;
  }
});

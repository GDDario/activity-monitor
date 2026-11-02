import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/database/migrations.dart';

void initializeDatabaseAtPath(String path) {
  final db = sqlite3.open(path);
  try {
    migrateDatabase(db);
  } finally {
    db.close();
  }
}

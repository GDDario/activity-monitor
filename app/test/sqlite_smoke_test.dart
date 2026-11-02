import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'SQLite persists and retrieves data after reopening a database',
    () async {
      final directory = await Directory.systemTemp.createTemp('sqlite_smoke_');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/smoke.db';

      final database = sqlite3.open(path);
      try {
        database.execute('CREATE TABLE smoke (value TEXT NOT NULL)');
        database.execute('INSERT INTO smoke (value) VALUES (?)', ['working']);
      } finally {
        database.close();
      }

      final reopened = sqlite3.open(path);
      try {
        expect(
          reopened.select('SELECT value FROM smoke').single['value'],
          'working',
        );
      } finally {
        reopened.close();
      }
    },
  );
}

import 'package:sqlite3/sqlite3.dart';

class DatabaseMigration {
  const DatabaseMigration(this.version, this.apply, {this.name, this.seeder});

  final int version;
  final void Function(Database database) apply;
  final String? name;
  final void Function(Database database)? seeder;

  String get migrationName =>
      name ?? 'migration_${version.toString().padLeft(4, '0')}';
}

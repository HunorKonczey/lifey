import 'package:drift/drift.dart';

/// Local cache of the shared exercise catalog.
@DataClassName('ExerciseRow')
class Exercises extends Table {
  @override
  String get tableName => 'exercises';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();

  /// Muscle group enum code (e.g. "CHEST"), null if not set.
  TextColumn get category => text().nullable()();

  /// Equipment enum code (e.g. "BARBELL"), null if not set.
  TextColumn get equipment => text().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

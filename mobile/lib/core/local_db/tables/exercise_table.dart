import 'package:drift/drift.dart';

/// Local cache of the shared exercise catalog.
@DataClassName('ExerciseRow')
class Exercises extends Table {
  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {clientId};
}

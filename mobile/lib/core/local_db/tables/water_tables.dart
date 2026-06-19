import 'package:drift/drift.dart';

@DataClassName('WaterSourceRow')
class WaterSources extends Table {
  @override
  String get tableName => 'water_sources';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  RealColumn get volumeLiters => real()();

  @override
  Set<Column> get primaryKey => {clientId};
}

@DataClassName('WaterEntryRow')
class WaterEntries extends Table {
  @override
  String get tableName => 'water_entries';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  // Nullable + informational only — see the backend's WaterEntry: the volume
  // is always a snapshot taken at logging time, never re-derived from the
  // source, so a missing/unsynced source never blocks this row.
  TextColumn get sourceClientId =>
      text().nullable().references(WaterSources, #clientId)();
  RealColumn get volumeLiters => real()();
  DateTimeColumn get consumedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {clientId};
}

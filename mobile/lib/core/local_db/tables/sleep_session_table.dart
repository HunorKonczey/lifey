import 'package:drift/drift.dart';

/// Local cache of sleep sessions imported from the health store
/// (docs/integrations/89 D-G7). One row per session, naps included.
/// `clientId` is the local primary key; `serverId` is filled in once the
/// create has synced.
///
/// There is no date column. The wake-up date ("last night") is derived from
/// [endedAt] in the device's time zone, the same as on the server.
@DataClassName('SleepSessionRow')
class SleepSessions extends Table {
  // Explicit — the sync engine looks tables up by this exact string.
  @override
  String get tableName => 'sleep_sessions';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();

  /// Stage minutes; null when the source app records no stages.
  IntColumn get asleepMinutes => integer().nullable()();
  IntColumn get deepMinutes => integer().nullable()();
  IntColumn get lightMinutes => integer().nullable()();
  IntColumn get remMinutes => integer().nullable()();
  IntColumn get awakeMinutes => integer().nullable()();

  /// The app that wrote the record to the store (e.g. "Garmin Connect").
  TextColumn get sourceAppName => text().nullable()();

  /// The store's record id: the importer's dedupe key (D-G3).
  TextColumn get healthRecordId => text().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

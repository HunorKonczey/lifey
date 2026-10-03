import 'package:drift/drift.dart';

/// Local cache of body measurements (docs/80). `clientId` is the local
/// primary key; `serverId` is filled in once the create has synced. `site` is
/// the backend enum name (`WAIST`, `CHEST`, `HIPS`, `ARM`, `THIGH`).
@DataClassName('BodyMeasurementRow')
class BodyMeasurements extends Table {
  // Explicit — the sync engine looks tables up by this exact string.
  @override
  String get tableName => 'body_measurements';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get site => text()();
  RealColumn get valueCm => real()();

  /// Local-only: when this device first saw the row. Orders same-day entries
  /// for one site so the newest is the day's value (docs/80 §6).
  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {clientId};
}

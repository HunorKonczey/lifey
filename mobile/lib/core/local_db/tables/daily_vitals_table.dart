import 'package:drift/drift.dart';

/// Local cache of daily vitals from the health store (docs/integrations/89
/// D-G8): one row per calendar day with the resting heart rate and the heart
/// rate variability. `clientId` is the local primary key; `serverId` is
/// filled in once the create has synced. A day has one row, enforced by the
/// repository's upsert by date, as for the daily step counts.
@DataClassName('DailyVitalsRow')
class DailyVitalsTable extends Table {
  // Explicit — the sync engine looks tables up by this exact string.
  @override
  String get tableName => 'daily_vitals';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get date => dateTime()();

  /// Resting heart rate in bpm.
  IntColumn get restingHr => integer().nullable()();

  /// Heart rate variability in milliseconds, measured by [hrvMethod].
  RealColumn get hrvMs => real().nullable()();

  /// `SDNN` (iOS) or `RMSSD` (Health Connect); set exactly when [hrvMs] is.
  TextColumn get hrvMethod => text().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

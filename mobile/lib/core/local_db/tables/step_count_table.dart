import 'package:drift/drift.dart';

/// One row per calendar day — the day's running step total.
/// `clientId` is the local PK (UUID); `serverId` is filled in after the
/// create syncs. A day can only ever have one row (enforced by the
/// repository's upsert-by-date logic).
@DataClassName('DailyStepCountRow')
class DailyStepCounts extends Table {
  @override
  String get tableName => 'daily_step_counts';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get date => dateTime()();
  IntColumn get steps => integer()();

  @override
  Set<Column> get primaryKey => {clientId};
}

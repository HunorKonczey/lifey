import 'package:drift/drift.dart';

/// Local cache of weight entries. `clientId` is the local primary key
/// (assigned on creation, online or offline); `serverId` is filled in once
/// the sync engine has created the row on the backend.
@DataClassName('WeightEntryRow')
class WeightEntries extends Table {
  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weight => real()();
  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {clientId};
}

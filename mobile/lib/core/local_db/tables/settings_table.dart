import 'package:drift/drift.dart';

/// Local cache of the per-user settings singleton.
@DataClassName('UserSettingsRow')
class UserSettingsTable extends Table {
  @override
  String get tableName => 'user_settings';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get unitSystem => text()(); // METRIC / IMPERIAL
  IntColumn get dailyCalorieGoal => integer().nullable()();
  IntColumn get dailyProteinGoal => integer().nullable()();
  IntColumn get dailyCarbsGoal => integer().nullable()();
  IntColumn get dailyFatGoal => integer().nullable()();
  RealColumn get dailyWaterGoalLiters => real().nullable()();
  TextColumn get theme => text()(); // LIGHT / DARK / SYSTEM

  @override
  Set<Column> get primaryKey => {clientId};
}

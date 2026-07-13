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
  // Added in schema v3, after rows already existed — needs a DEFAULT so
  // `ALTER TABLE ADD COLUMN` is valid for existing (non-empty) tables.
  TextColumn get language => text().withDefault(const Constant('SYSTEM'))(); // SYSTEM / ENGLISH / HUNGARIAN
  // Added in schema v9.
  IntColumn get dailyStepGoal => integer().nullable()();
  // Added in schema v24 (docs/30-push-notifications-plan.md) — needs a
  // DEFAULT for the same reason as `language` above.
  BoolColumn get workoutReminderEnabled => boolean().withDefault(const Constant(true))();
  // Added in schema v25 (docs/31-session-feedback-loop-plan.md) — needs a
  // DEFAULT for the same reason as `language` above.
  BoolColumn get trainerCommentPushEnabled => boolean().withDefault(const Constant(true))();
  // Added in schema v26 (docs/32-trainer-nutrition-goals-plan.md) — needs a
  // DEFAULT for the same reason as `language` above.
  BoolColumn get trainerGoalsPushEnabled => boolean().withDefault(const Constant(true))();
  // Added in schema v27 (docs/34-multi-week-program-plan.md, M6) — needs a
  // DEFAULT for the same reason as `language` above.
  BoolColumn get programAssignedPushEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {clientId};
}

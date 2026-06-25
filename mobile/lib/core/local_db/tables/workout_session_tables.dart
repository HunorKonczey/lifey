import 'package:drift/drift.dart';

import 'exercise_table.dart';

@DataClassName('WorkoutSessionRow')
class WorkoutSessions extends Table {
  @override
  String get tableName => 'workout_sessions';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// Active energy burned (kcal), imported from Apple Health.
  RealColumn get activeCalories => real().nullable()();

  /// Average heart rate (bpm) over the workout, imported from Apple Health.
  RealColumn get averageHeartRate => real().nullable()();

  /// HKWorkout UUID this session was paired with, if imported from Apple Health.
  TextColumn get healthWorkoutId => text().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

/// Exercises planned for a session (quick-add defaults) — independent of how
/// many [ExerciseSets] have been logged for them. Mirrors the backend's
/// `workout_session_exercises` snapshot table.
@DataClassName('WorkoutSessionExerciseRow')
class WorkoutSessionExercises extends Table {
  @override
  String get tableName => 'workout_session_exercises';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get sessionClientId => text().references(WorkoutSessions, #clientId)();
  TextColumn get exerciseClientId => text().references(Exercises, #clientId)();

  /// Target number of sets for this exercise in this session, null if not set.
  IntColumn get targetSets => integer().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

@DataClassName('ExerciseSetRow')
class ExerciseSets extends Table {
  @override
  String get tableName => 'exercise_sets';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get sessionClientId => text().references(WorkoutSessions, #clientId)();
  TextColumn get exerciseClientId => text().references(Exercises, #clientId)();
  IntColumn get reps => integer()();
  RealColumn get weight => real()();

  /// The instant this set was logged — used to compute rest time between
  /// consecutive sets. Backfilled from the owning session's `startedAt` for
  /// rows that predate this column (see AppDatabase's schema v6 migration).
  DateTimeColumn get performedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {clientId};
}

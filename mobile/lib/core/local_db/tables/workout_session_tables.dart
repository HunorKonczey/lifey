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

  @override
  Set<Column> get primaryKey => {clientId};
}

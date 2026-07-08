import 'package:drift/drift.dart';

import 'exercise_table.dart';

@DataClassName('WorkoutSessionRow')
class WorkoutSessions extends Table {
  @override
  String get tableName => 'workout_sessions';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();

  /// Null for a trainer-scheduled session that hasn't been started yet (see
  /// [scheduledFor]) — docs/personal_trainer/08-utemezett-edzesek-koncepcio.md.
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// Calendar day the trainer scheduled this session for; null for a normal
  /// (client-started) session. Non-null with [startedAt] null means
  /// "upcoming" (or "missed", once the date has passed). Stored as a
  /// midnight-local `DateTime` (no dedicated date-only column type in Drift).
  DateTimeColumn get scheduledFor => dateTime().nullable()();

  /// Optional wall-clock time ("HH:mm"), copied from the schedule's time of
  /// day; display/ordering only, stored as text since it has no time zone.
  TextColumn get scheduledTime => text().nullable()();

  /// The originating schedule's server id. Not a `.references()` FK — the
  /// schedule definition itself is never synced to the client, only its
  /// materialized session rows.
  IntColumn get scheduleId => integer().nullable()();

  /// Active energy burned (kcal), imported from Apple Health.
  RealColumn get activeCalories => real().nullable()();

  /// Average heart rate (bpm) over the workout, imported from Apple Health.
  RealColumn get averageHeartRate => real().nullable()();

  /// HKWorkout UUID this session was paired with, if imported from Apple Health.
  TextColumn get healthWorkoutId => text().nullable()();

  /// clientId of the template this session was started from, if any. Not a
  /// Drift `.references()` FK — deleting a template must not be blocked by
  /// (or cascade into) sessions that were started from it.
  TextColumn get templateClientId => text().nullable()();

  /// Snapshot of the template's name at the time this session was started,
  /// so the session still shows what it was called even if the template is
  /// later renamed or deleted.
  TextColumn get templateName => text().nullable()();

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

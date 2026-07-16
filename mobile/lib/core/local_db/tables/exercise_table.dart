import 'package:drift/drift.dart';

/// Local cache of the shared exercise catalog.
@DataClassName('ExerciseRow')
class Exercises extends Table {
  @override
  String get tableName => 'exercises';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();

  /// Muscle group enum code (e.g. "CHEST"), null if not set.
  TextColumn get category => text().nullable()();

  /// Equipment enum code (e.g. "BARBELL"), null if not set.
  TextColumn get equipment => text().nullable()();

  /// Free-text notes (e.g. machine setting), null if not set.
  TextColumn get description => text().nullable()();

  /// Non-null only for a trainer-assigned copy (docs/personal_trainer/05-mobil-terv.md
  /// §2) — the trainer's server-side user id, drives the "Edzőtől" badge.
  IntColumn get originTrainerId => integer().nullable()();

  /// Per-exercise rest-timer override in seconds (docs/39-rest-timer-plan.md
  /// §2.2) — null means "use the user's default rest duration".
  IntColumn get defaultRestSeconds => integer().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

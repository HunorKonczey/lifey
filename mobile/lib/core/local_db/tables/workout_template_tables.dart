import 'package:drift/drift.dart';

import 'exercise_table.dart';

@DataClassName('WorkoutTemplateRow')
class WorkoutTemplates extends Table {
  @override
  String get tableName => 'workout_templates';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();

  /// Non-null only for a trainer-assigned copy (docs/personal_trainer/05-mobil-terv.md
  /// §2) — the trainer's server-side user id, drives the "Edzőtől" badge.
  IntColumn get originTrainerId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

@DataClassName('WorkoutTemplateExerciseRow')
class WorkoutTemplateExercises extends Table {
  @override
  String get tableName => 'workout_template_exercises';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get templateClientId => text().references(WorkoutTemplates, #clientId)();
  TextColumn get exerciseClientId => text().references(Exercises, #clientId)();

  /// Target number of sets for this exercise in the template, null if not set.
  IntColumn get targetSets => integer().nullable()();

  /// Display order within the template (0-based). Matches the server-side
  /// sort_order column so the pull engine can round-trip it faithfully.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {clientId};
}

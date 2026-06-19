import 'package:drift/drift.dart';

import 'exercise_table.dart';

@DataClassName('WorkoutTemplateRow')
class WorkoutTemplates extends Table {
  @override
  String get tableName => 'workout_templates';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();

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

  @override
  Set<Column> get primaryKey => {clientId};
}

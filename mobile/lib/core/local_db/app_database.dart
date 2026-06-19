import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/exercise_table.dart';
import 'tables/food_table.dart';
import 'tables/meal_tables.dart';
import 'tables/pending_operations_table.dart';
import 'tables/recipe_tables.dart';
import 'tables/settings_table.dart';
import 'tables/water_tables.dart';
import 'tables/weight_table.dart';
import 'tables/workout_session_tables.dart';
import 'tables/workout_template_tables.dart';

part 'app_database.g.dart';

/// The on-device cache backing offline-first reads/writes. Every table has a
/// local `clientId` (its primary key, assigned on creation whether online or
/// offline) and a nullable `serverId`, filled in once a create has synced.
///
/// This is schema-only for now: repositories still talk to the API directly.
/// [PendingOperations] is the offline-write queue ("outbox") that the sync
/// engine will drain — connectivity-triggered draining, clientId/serverId
/// reconciliation, and dependency ordering are separate, later pieces of
/// work that build on this database.
@DriftDatabase(tables: [
  WeightEntries,
  Foods,
  Recipes,
  RecipeIngredients,
  Meals,
  MealEntries,
  Exercises,
  WorkoutTemplates,
  WorkoutTemplateExercises,
  WorkoutSessions,
  WorkoutSessionExercises,
  ExerciseSets,
  WaterSources,
  WaterEntries,
  UserSettingsTable,
  PendingOperations,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'lifey.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

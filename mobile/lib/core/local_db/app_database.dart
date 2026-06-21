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
/// Repositories under `lib/features/*/data/` read and write this database
/// exclusively (never `dio` directly). [PendingOperations] is the
/// offline-write queue ("outbox") that `SyncEngine` drains; `PullEngine`
/// refreshes this cache from the backend. Both are driven by
/// `ConnectivitySyncController` (see `lib/core/sync/`).
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // V2: barcode scanner support — foods can be tagged with a barcode.
          if (from < 2) {
            await m.addColumn(foods, foods.barcode);
          }
        },
      );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'lifey.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

import '../local_db/app_database.dart';

/// Deletes an entity's child/junction rows once its own delete is confirmed
/// by the server — see [EntitySyncConfig.cleanupChildren].
typedef ChildCleanup = Future<void> Function(AppDatabase db, String clientId);

Future<void> _cleanupMealChildren(AppDatabase db, String clientId) =>
    (db.delete(db.mealEntries)..where((t) => t.mealClientId.equals(clientId))).go();

Future<void> _cleanupRecipeChildren(AppDatabase db, String clientId) =>
    (db.delete(db.recipeIngredients)..where((t) => t.recipeClientId.equals(clientId))).go();

Future<void> _cleanupWorkoutTemplateChildren(AppDatabase db, String clientId) =>
    (db.delete(db.workoutTemplateExercises)..where((t) => t.templateClientId.equals(clientId)))
        .go();

Future<void> _cleanupWorkoutSessionChildren(AppDatabase db, String clientId) async {
  await (db.delete(db.workoutSessionExercises)..where((t) => t.sessionClientId.equals(clientId)))
      .go();
  await (db.delete(db.exerciseSets)..where((t) => t.sessionClientId.equals(clientId))).go();
}

/// How a top-level entity type maps to its local table and REST endpoint.
class EntitySyncConfig {
  const EntitySyncConfig({
    required this.tableName,
    required this.basePath,
    this.isSingleton = false,
    this.cleanupChildren,
  });

  /// The exact SQL table name (matches each table's `tableName` override).
  final String tableName;

  /// REST collection path, e.g. `/weights`.
  final String basePath;

  /// True only for `user_settings`: there's no POST, just GET (lazy-create)
  /// and PUT — both a local "create" and "update" operation map to the same
  /// PUT, and the response has no `id` field to capture.
  final bool isSingleton;

  /// For entities with child/junction rows (meal entries, recipe
  /// ingredients, ...): the row and its children all stay put while a
  /// delete is in flight (only hidden from list UIs, so a server rejection
  /// can bring it back with its content intact and a failed-sync marker —
  /// see e.g. `MealController.build`). This runs in
  /// [SyncEngine._applySuccess] once the server actually confirms the
  /// delete, right before the parent row itself is removed.
  final ChildCleanup? cleanupChildren;
}

/// Registry for every entity type that gets its own [PendingOperations] row.
const entitySyncConfigs = <String, EntitySyncConfig>{
  'weight_entry': EntitySyncConfig(tableName: 'weight_entries', basePath: '/weights'),
  'food': EntitySyncConfig(tableName: 'foods', basePath: '/foods'),
  'recipe': EntitySyncConfig(
    tableName: 'recipes',
    basePath: '/recipes',
    cleanupChildren: _cleanupRecipeChildren,
  ),
  'meal': EntitySyncConfig(
    tableName: 'meals',
    basePath: '/meals',
    cleanupChildren: _cleanupMealChildren,
  ),
  'exercise': EntitySyncConfig(tableName: 'exercises', basePath: '/exercises'),
  'workout_template': EntitySyncConfig(
    tableName: 'workout_templates',
    basePath: '/workout-templates',
    cleanupChildren: _cleanupWorkoutTemplateChildren,
  ),
  'workout_session': EntitySyncConfig(
    tableName: 'workout_sessions',
    basePath: '/workout-sessions',
    cleanupChildren: _cleanupWorkoutSessionChildren,
  ),
  'water_source': EntitySyncConfig(tableName: 'water_sources', basePath: '/water-sources'),
  'water_entry': EntitySyncConfig(tableName: 'water_entries', basePath: '/water-entries'),
  'user_settings':
      EntitySyncConfig(tableName: 'user_settings', basePath: '/settings', isSingleton: true),
};

/// Every local entity table a clientId could belong to — used to resolve a
/// `clientRef:<uuid>` placeholder to its serverId without the caller needing
/// to know which table it's in (clientIds are UUIDs, so at most one matches).
const allEntityTableNames = [
  'weight_entries',
  'foods',
  'recipes',
  'meals',
  'exercises',
  'workout_templates',
  'workout_sessions',
  'water_sources',
  'water_entries',
  'user_settings',
];

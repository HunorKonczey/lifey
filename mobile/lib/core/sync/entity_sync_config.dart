/// How a top-level entity type maps to its local table and REST endpoint.
class EntitySyncConfig {
  const EntitySyncConfig({
    required this.tableName,
    required this.basePath,
    this.isSingleton = false,
  });

  /// The exact SQL table name (matches each table's `tableName` override).
  final String tableName;

  /// REST collection path, e.g. `/weights`.
  final String basePath;

  /// True only for `user_settings`: there's no POST, just GET (lazy-create)
  /// and PUT — both a local "create" and "update" operation map to the same
  /// PUT, and the response has no `id` field to capture.
  final bool isSingleton;
}

/// Registry for every entity type that gets its own [PendingOperations] row.
/// Child/junction data (recipe ingredients, meal entries, template/session
/// exercises, sets) isn't listed — it's embedded in its parent's payload.
const entitySyncConfigs = <String, EntitySyncConfig>{
  'weight_entry': EntitySyncConfig(tableName: 'weight_entries', basePath: '/weights'),
  'food': EntitySyncConfig(tableName: 'foods', basePath: '/foods'),
  'recipe': EntitySyncConfig(tableName: 'recipes', basePath: '/recipes'),
  'meal': EntitySyncConfig(tableName: 'meals', basePath: '/meals'),
  'exercise': EntitySyncConfig(tableName: 'exercises', basePath: '/exercises'),
  'workout_template':
      EntitySyncConfig(tableName: 'workout_templates', basePath: '/workout-templates'),
  'workout_session':
      EntitySyncConfig(tableName: 'workout_sessions', basePath: '/workout-sessions'),
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

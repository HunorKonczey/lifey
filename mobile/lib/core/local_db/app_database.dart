import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../sync/client_ref.dart';
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
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // V2: barcode scanner support — foods can be tagged with a barcode.
          if (from < 2) {
            await m.addColumn(foods, foods.barcode);
          }
          // V3: UI language preference, synced like theme.
          if (from < 3) {
            await m.addColumn(userSettingsTable, userSettingsTable.language);
          }
          // V4: no schema change — meals used to queue their `dateTime` as a
          // zone-less string the backend has since stopped accepting, so any
          // meal create/update that failed to sync before this fix is stuck
          // with that stale payload baked in (retrying it just resends the
          // same unparseable string). Rebuild those payloads from the
          // still-correct local row and let them retry.
          if (from < 4) {
            await _fixStaleMealOutboxPayloads();
          }
          // V5: recipes can be marked as favorite.
          if (from < 5) {
            await m.addColumn(recipes, recipes.favorite);
          }
          // V6: sets carry a performedAt timestamp (for rest-time display).
          // Added via raw SQL rather than m.addColumn because the column is
          // NOT NULL with no constant default — SQLite still allows that via
          // ALTER TABLE ... ADD COLUMN ... NOT NULL DEFAULT <literal>, with
          // the literal immediately overwritten per row by the backfill.
          if (from < 6) {
            await _addExerciseSetPerformedAtColumn();
          }
        },
      );

  Future<void> _addExerciseSetPerformedAtColumn() async {
    await customStatement(
      'ALTER TABLE exercise_sets ADD COLUMN performed_at INTEGER NOT NULL DEFAULT 0',
    );
    // Existing sets have no recoverable timestamp, so they're backfilled
    // from their session's startedAt — same convention as the backend's
    // V14__exercise_set_performed_at.sql migration.
    await customStatement('''
      UPDATE exercise_sets
      SET performed_at = (
        SELECT ws.started_at FROM workout_sessions ws
        WHERE ws.client_id = exercise_sets.session_client_id
      )
    ''');
  }

  Future<void> _fixStaleMealOutboxPayloads() async {
    final staleOps = await (select(pendingOperations)
          ..where((t) => t.entityType.equals('meal') & t.status.equals('failed')))
        .get();

    for (final op in staleOps) {
      final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
      final dateTimeStr = payload['dateTime'] as String?;
      // The fixed client always sends a UTC ('...Z') timestamp — anything
      // without it is a pre-fix payload that needs rebuilding.
      if (dateTimeStr == null || dateTimeStr.contains('Z')) continue;

      final mealRow =
          await (select(meals)..where((t) => t.clientId.equals(op.clientId))).getSingleOrNull();
      if (mealRow == null) {
        // No local row to rebuild from (e.g. deleted offline) — drop it.
        await (delete(pendingOperations)..where((t) => t.id.equals(op.id))).go();
        continue;
      }

      final entryRows = await (select(mealEntries)
            ..where((t) => t.mealClientId.equals(op.clientId)))
          .get();
      final rebuiltPayload = {
        'dateTime': mealRow.mealDateTime.toUtc().toIso8601String(),
        'mealType': payload['mealType'],
        'entries': entryRows
            .map((e) => {
                  'foodId': clientRef(e.foodClientId),
                  'quantityInGrams': e.quantityInGrams,
                })
            .toList(),
      };

      await (update(pendingOperations)..where((t) => t.id.equals(op.id))).write(
        PendingOperationsCompanion(
          payloadJson: Value(jsonEncode(rebuiltPayload)),
          status: const Value('pending'),
          lastError: const Value(null),
        ),
      );
    }
  }

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'lifey.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

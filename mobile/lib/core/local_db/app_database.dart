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
import 'tables/step_count_table.dart';
import 'tables/sync_cursor_table.dart';
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
  DailyStepCounts,
  SyncCursors,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 28;

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
          // V7: Apple Health import fields on workout sessions (all nullable,
          // no backfill — pre-existing sessions simply weren't imported).
          if (from < 7) {
            await m.addColumn(workoutSessions, workoutSessions.activeCalories);
            await m.addColumn(workoutSessions, workoutSessions.averageHeartRate);
            await m.addColumn(workoutSessions, workoutSessions.healthWorkoutId);
          }
          // V8: offline-first daily step counts (one row per day, upserted as
          // the running total accumulates throughout the day).
          if (from < 8) {
            await m.createTable(dailyStepCounts);
          }
          // V9: daily step goal added to user settings.
          if (from < 9) {
            await m.addColumn(userSettingsTable, userSettingsTable.dailyStepGoal);
          }
          // V10: exercise category (muscle group) and equipment — both nullable,
          // existing exercises stay uncategorized until edited.
          if (from < 10) {
            await m.addColumn(exercises, exercises.category);
            await m.addColumn(exercises, exercises.equipment);
          }
          // V11: target set count per exercise in a workout template — nullable,
          // pre-existing template links carry no set target until updated.
          if (from < 11) {
            await m.addColumn(workoutTemplateExercises, workoutTemplateExercises.targetSets);
          }
          // V12: display order for exercises within a template. Pre-existing
          // links get sort_order = 0 (the column default); order is restored
          // after the next save or server pull.
          if (from < 12) {
            await m.addColumn(workoutTemplateExercises, workoutTemplateExercises.sortOrder);
          }
          // V13: target set count per exercise in a workout session — nullable,
          // pre-existing session exercises carry no set target.
          if (from < 13) {
            await m.addColumn(workoutSessionExercises, workoutSessionExercises.targetSets);
          }
          // V14: hidden flag on foods — quick-entry macros are stored as foods
          // with hidden=true so they don't appear in the catalog or autocomplete.
          if (from < 14) {
            await m.addColumn(foods, foods.hidden);
          }
          // V15: a recipe stores how many servings it yields; pre-existing
          // recipes default to 1 (the column default).
          if (from < 15) {
            await m.addColumn(recipes, recipes.servings);
          }
          // V16: meals can carry an optional name (set when logging from a recipe).
          if (from < 16) {
            await m.addColumn(meals, meals.name);
          }
          // V17: workout sessions record which template they were started
          // from, if any — the template's clientId plus a name snapshot.
          if (from < 17) {
            await m.addColumn(workoutSessions, workoutSessions.templateClientId);
            await m.addColumn(workoutSessions, workoutSessions.templateName);
          }
          // V18: per-entity delta-sync cursor (docs/15-delta-sync.md). No
          // rows yet for any entity means every _pull* still takes the
          // full-pull bootstrap path until its first successful delta pull.
          if (from < 18) {
            await m.createTable(syncCursors);
          }
          // V19: trainer-assignment provenance (docs/personal_trainer/05-mobil-terv.md
          // §2) — nullable, existing rows simply have no "Edzőtől" badge until
          // the next pull re-fetches them with the new field populated.
          if (from < 19) {
            await m.addColumn(foods, foods.originTrainerId);
            await m.addColumn(exercises, exercises.originTrainerId);
            await m.addColumn(recipes, recipes.originTrainerId);
            await m.addColumn(workoutTemplates, workoutTemplates.originTrainerId);
          }
          // V20: trainer-scheduled ("upcoming") workout sessions (docs/personal_trainer/
          // 09-utemezett-edzesek-domain-backend.md) — scheduledFor/scheduledTime/scheduleId
          // are new, and startedAt's NOT NULL constraint is dropped (null = not started
          // yet). Constraint changes aren't ALTER COLUMN-able in SQLite, so the whole
          // table is recreated from the current (already-updated) schema and refilled.
          if (from < 20) {
            await m.alterTable(TableMigration(
              workoutSessions,
              newColumns: [
                workoutSessions.scheduledFor,
                workoutSessions.scheduledTime,
                workoutSessions.scheduleId,
              ],
            ));
          }
          // V21: free-text description/notes (e.g. machine setting) per exercise.
          if (from < 21) {
            await m.addColumn(exercises, exercises.description);
          }
          // V22: recipe photos (docs/22-profile-picture-plan.md's pattern,
          // applied to recipes) — nullable, existing recipes simply have no
          // photo until the next pull or an explicit upload sets it.
          if (from < 22) {
            await m.addColumn(recipes, recipes.imageUpdatedAt);
          }
          // V23: post-workout difficulty rating (RPE 1-10) + optional note,
          // captured after finishing a session — nullable, existing sessions
          // simply stay unrated.
          if (from < 23) {
            await m.addColumn(workoutSessions, workoutSessions.rpe);
            await m.addColumn(workoutSessions, workoutSessions.feedbackNote);
          }
          // V24: workout-reminder push opt-out (docs/30-push-notifications-plan.md)
          // — defaults true (the column default), matching the backend.
          if (from < 24) {
            await m.addColumn(userSettingsTable, userSettingsTable.workoutReminderEnabled);
          }
          // V25: trainer comment on a session (docs/31-session-feedback-loop-plan.md)
          // — nullable, existing sessions simply stay uncommented — plus its
          // push opt-out, defaulting true like every other push preference.
          if (from < 25) {
            await m.addColumn(workoutSessions, workoutSessions.trainerComment);
            await m.addColumn(workoutSessions, workoutSessions.trainerCommentAt);
            await m.addColumn(userSettingsTable, userSettingsTable.trainerCommentPushEnabled);
          }
          // V26: trainer-nutrition-goals-changed push opt-out
          // (docs/32-trainer-nutrition-goals-plan.md) — defaults true, same
          // shape as every other push preference here.
          if (from < 26) {
            await m.addColumn(userSettingsTable, userSettingsTable.trainerGoalsPushEnabled);
          }
          // V27: program-assigned push opt-out
          // (docs/34-multi-week-program-plan.md, M6) — defaults true, same
          // shape as every other push preference here.
          if (from < 27) {
            await m.addColumn(userSettingsTable, userSettingsTable.programAssignedPushEnabled);
          }
          // V28: rest timer (docs/39-rest-timer-plan.md) — master toggle
          // (defaults true) and default duration (defaults 90s) on
          // settings, plus a nullable per-exercise override.
          if (from < 28) {
            await m.addColumn(userSettingsTable, userSettingsTable.restTimerEnabled);
            await m.addColumn(userSettingsTable, userSettingsTable.defaultRestSeconds);
            await m.addColumn(exercises, exercises.defaultRestSeconds);
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

  /// Wipes every local table. Called on logout so the next signed-in
  /// account never sees the previous account's cached data (settings,
  /// weight, meals, workouts, etc.) before its own data has re-synced.
  Future<void> clearAllData() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'lifey.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

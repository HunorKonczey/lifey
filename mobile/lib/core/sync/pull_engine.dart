import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local_db/app_database.dart';
import '../local_db/database_provider.dart';
import '../network/dio_client.dart';
import 'client_id.dart';
import 'sync_engine_provider.dart';
import 'sync_lock.dart';

/// Refreshes the local cache from the backend: call on app start or when
/// connectivity returns, after [SyncEngine.sync] has had a chance to push
/// anything queued (so a just-created row already carries its serverId and
/// isn't duplicated by the pull).
///
/// The rule for every table: a local row with a pending operation is left
/// alone (the local edit hasn't synced yet, so it — not the possibly-stale
/// server copy — is the source of truth); everything else is overwritten
/// from the server response, and a serverId that no longer appears in the
/// response is deleted locally (it was removed server-side, or by another
/// device). Once a row's pending operations have drained, server data is
/// the source of truth, per doc section 7.
class PullEngine {
  PullEngine(this._db, this._dio, [SyncLock? lock]) : _lock = lock ?? SyncLock();

  final AppDatabase _db;
  final Dio _dio;
  final SyncLock _lock;

  bool _running = false;

  /// Coalesces concurrent calls (same pattern as [SyncEngine.sync]): without
  /// this, the startup auto-refresh and a manual pull-to-refresh fired
  /// shortly after can run two [pullAll] passes at once. Each per-entity
  /// pull does an un-transacted delete-then-reinsert of child rows (meal
  /// entries, recipe ingredients, ...), so two interleaved passes can have
  /// one pass's delete land after the other's insert — wiping a child
  /// aggregate (e.g. a recipe's ingredients) even though the server data
  /// was correct the whole time.
  Future<void> pullAll() async {
    if (_running) return;
    _running = true;
    debugPrint('PullEngine: pullAll START');
    try {
      // Serialized against SyncEngine.sync via the shared lock (see
      // SyncLock) — see that class doc for why a pull can't be allowed to
      // run concurrently with a push.
      await _lock.synchronized(() async {
        // Order matters: entities referenced by others (as a clientId
        // lookup) are pulled first.
        //
        // Each entity is pulled in its own guard so a failure in one — a
        // malformed payload, an unexpected null, or a duplicate-serverId
        // collision that makes `getSingleOrNull()` throw — can't abort the
        // whole refresh and leave every *later* entity (water, steps,
        // meals…) stale. The failing entity keeps its last-known local
        // state and is retried on the next pull; the rest still refresh.
        // Without this, the first throwing entity (foods) silently stops
        // the entire sync — the only network call that goes out is its GET.
        await _guard('foods', _pullFoods);
        await _guard('exercises', _pullExercises);
        await _guard('water_sources', _pullWaterSources);
        await _guard('weight_entries', _pullWeightEntries);
        await _guard('water_entries', _pullWaterEntries);
        await _guard('daily_steps', _pullDailySteps);
        await _guard('settings', _pullSettings);
        await _guard('workout_templates', _pullWorkoutTemplates);
        await _guard('cardio_interval_plans', _pullCardioIntervalPlans);
        await _guard('workout_sessions', _pullWorkoutSessions);
        await _guard('recipes', _pullRecipes);
        await _guard('meals', _pullMeals);
      });
    } finally {
      _running = false;
      debugPrint('PullEngine: pullAll DONE');
    }
  }

  /// Runs a single entity pull, swallowing (and logging) any error so the
  /// remaining entities in [pullAll] still get refreshed.
  Future<void> _guard(String entity, Future<void> Function() pull) async {
    try {
      await pull();
      debugPrint('PullEngine: $entity OK');
    } on DioException catch (e) {
      // HTTP failures are routine (e.g. a 401 when a pull races a login or
      // logout — see AuthInterceptor) and get retried on the next pull, so a
      // one-line status is enough; the full multi-line DioException.toString()
      // plus a Dart stack trace per entity is what was making this log
      // unreadable.
      debugPrint('PullEngine: $entity FAILED (${e.response?.statusCode ?? e.type}), continuing');
    } catch (e, st) {
      debugPrint('PullEngine: $entity FAILED, continuing: $e\n$st');
    }
  }

  /// Re-fetches a handful of already-applied rows on every delta pull rather
  /// than trusting the exact boundary timestamp — the mitigation for
  /// concurrent-write clock skew described in docs/15-delta-sync.md §4(c).
  /// Harmless: re-applying an already-current row is just an idempotent
  /// upsert (or a delete-of-an-already-deleted row, also a no-op).
  static const _cursorOverlap = Duration(seconds: 10);

  Future<void> _pullFoods() async {
    // Foods is the pilot entity for delta sync (docs/15-delta-sync.md). No
    // cursor yet (first sync ever, or first sync since this device installed
    // a delta-sync-capable build) means a full bootstrap pull, exactly as
    // before; a cursor means only what changed since then is fetched.
    //
    // Either way, the local `foods` table must still end up a complete
    // mirror of every non-hidden, non-deleted server row — foodSearchProvider's
    // meal-entry autocomplete (mobile/lib/features/nutrition/application/food_controller.dart)
    // depends on searching the full local cache, not just the paginated
    // window shown in the Foods tab.
    final cursor = await _getSyncCursor('foods');
    if (cursor == null) {
      await _pullFoodsFull();
    } else {
      await _pullFoodsDelta(cursor);
    }
  }

  Future<void> _pullFoodsFull() async {
    final items = await _getAllPages('/foods', size: 200);
    final seen = <int>{};
    DateTime? maxUpdatedAt;
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      await _upsertFood(json);
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    await _deleteMissing('foods', seen, additionalWhere: 'AND hidden = false');
    // An empty catalog leaves maxUpdatedAt null, so no cursor is seeded —
    // the next pull just takes this same full-pull branch again, which is
    // correct and cheap (nothing to pull) until the first food exists.
    if (maxUpdatedAt != null) {
      await _setSyncCursor('foods', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _pullFoodsDelta(DateTime since) async {
    final items = await _getAllPages(
      '/foods',
      size: 200,
      extraQueryParameters: {'updatedSince': since.toUtc().toIso8601String()},
    );
    DateTime? maxUpdatedAt;
    for (final json in items) {
      if (json['deletedAt'] != null) {
        await _deleteFoodTombstone(json['id'] as int);
      } else {
        await _upsertFood(json);
      }
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    // No rows changed since the last pull — leave the cursor as-is rather
    // than advancing it to "now" (which would be the client-clock mistake
    // docs/15-delta-sync.md §4(a) warns against).
    if (maxUpdatedAt != null) {
      await _setSyncCursor('foods', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _upsertFood(Map<String, dynamic> json) async {
    final serverId = json['id'] as int;
    final existingClientId = await _localClientId('foods', serverId);
    if (existingClientId != null && await _hasPendingOperation(existingClientId)) return;

    final values = FoodsCompanion(
      name: Value(json['name'] as String),
      caloriesPer100g: Value((json['caloriesPer100g'] as num).toDouble()),
      proteinPer100g: Value((json['proteinPer100g'] as num).toDouble()),
      carbsPer100g: Value((json['carbsPer100g'] as num?)?.toDouble()),
      fatPer100g: Value((json['fatPer100g'] as num?)?.toDouble()),
      barcode: Value(json['barcode'] as String?),
      hidden: Value(json['hidden'] as bool? ?? false),
      originTrainerId: Value(json['originTrainerId'] as int?),
    );
    if (existingClientId != null) {
      await (_db.update(_db.foods)..where((t) => t.clientId.equals(existingClientId)))
          .write(values);
    } else {
      await _db.into(_db.foods).insert(
            values.copyWith(clientId: Value(newClientId()), serverId: Value(serverId)),
          );
    }
  }

  /// Applies a delta-feed tombstone: deletes the local row for [serverId] if
  /// present and not itself mid-sync. Unlike [_pullFoodsFull]'s
  /// `_deleteMissing`, this never touches rows the feed didn't mention.
  Future<void> _deleteFoodTombstone(int serverId) async {
    final clientId = await _localClientId('foods', serverId);
    if (clientId == null) return; // already absent locally — nothing to do
    if (await _hasPendingOperation(clientId)) return;
    await (_db.delete(_db.foods)..where((t) => t.clientId.equals(clientId))).go();
    // customStatement-free delete already notifies watchers via Drift's own
    // table-change tracking, unlike _deleteMissing's raw customStatement path.
  }

  DateTime? _maxUpdatedAt(DateTime? current, Map<String, dynamic> json) {
    final raw = json['updatedAt'] as String?;
    if (raw == null) return current;
    final parsed = DateTime.parse(raw).toUtc();
    if (current == null || parsed.isAfter(current)) return parsed;
    return current;
  }

  Future<DateTime?> _getSyncCursor(String entityType) async {
    final row = await (_db.select(_db.syncCursors)
          ..where((t) => t.entityType.equals(entityType)))
        .getSingleOrNull();
    return row?.lastSyncedAt;
  }

  Future<void> _setSyncCursor(String entityType, DateTime value) async {
    await _db.into(_db.syncCursors).insertOnConflictUpdate(
          SyncCursorsCompanion(
            entityType: Value(entityType),
            lastSyncedAt: Value(value),
          ),
        );
  }

  Future<void> _pullExercises() async {
    final cursor = await _getSyncCursor('exercises');
    if (cursor == null) {
      await _pullExercisesFull();
    } else {
      await _pullExercisesDelta(cursor);
    }
  }

  Future<void> _pullExercisesFull() async {
    final items = await _getList('/exercises');
    final seen = <int>{};
    DateTime? maxUpdatedAt;
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      await _upsertExercise(json);
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    await _deleteMissing('exercises', seen);
    if (maxUpdatedAt != null) {
      await _setSyncCursor('exercises', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _pullExercisesDelta(DateTime since) async {
    final items = await _getAllPages(
      '/exercises',
      size: 200,
      extraQueryParameters: {'updatedSince': since.toUtc().toIso8601String()},
    );
    DateTime? maxUpdatedAt;
    for (final json in items) {
      if (json['deletedAt'] != null) {
        await _deleteExerciseTombstone(json['id'] as int);
      } else {
        await _upsertExercise(json);
      }
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    if (maxUpdatedAt != null) {
      await _setSyncCursor('exercises', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _upsertExercise(Map<String, dynamic> json) async {
    final serverId = json['id'] as int;
    final existingClientId = await _localClientId('exercises', serverId);
    if (existingClientId != null && await _hasPendingOperation(existingClientId)) return;

    final values = ExercisesCompanion(
      name: Value(json['name'] as String),
      category: Value(json['category'] as String?),
      equipment: Value(json['equipment'] as String?),
      description: Value(json['description'] as String?),
      originTrainerId: Value(json['originTrainerId'] as int?),
      defaultRestSeconds: Value(json['defaultRestSeconds'] as int?),
    );
    if (existingClientId != null) {
      await (_db.update(_db.exercises)..where((t) => t.clientId.equals(existingClientId)))
          .write(values);
    } else {
      await _db.into(_db.exercises).insert(
            values.copyWith(clientId: Value(newClientId()), serverId: Value(serverId)),
          );
    }
  }

  /// Mirrors [_deleteFoodTombstone]: exercises are shared/referenced (by
  /// workout templates and sessions) the same way foods are, so a tombstoned
  /// exercise is deleted locally the same way — dangling references left in
  /// local template/session child rows are a pre-existing gap (see
  /// docs/16-delta-sync-rollout.md §1), not something this pull introduces.
  Future<void> _deleteExerciseTombstone(int serverId) async {
    final clientId = await _localClientId('exercises', serverId);
    if (clientId == null) return;
    if (await _hasPendingOperation(clientId)) return;
    await (_db.delete(_db.exercises)..where((t) => t.clientId.equals(clientId))).go();
  }

  Future<void> _pullWaterSources() async {
    final items = await _getList('/water-sources');
    final seen = <int>{};
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      final existingClientId = await _localClientId('water_sources', serverId);
      if (existingClientId != null && await _hasPendingOperation(existingClientId)) continue;

      final values = WaterSourcesCompanion(
        name: Value(json['name'] as String),
        volumeLiters: Value((json['volumeLiters'] as num).toDouble()),
      );
      if (existingClientId != null) {
        await (_db.update(_db.waterSources)..where((t) => t.clientId.equals(existingClientId)))
            .write(values);
      } else {
        await _db.into(_db.waterSources).insert(
              values.copyWith(clientId: Value(newClientId()), serverId: Value(serverId)),
            );
      }
    }
    await _deleteMissing('water_sources', seen);
  }

  Future<void> _pullWeightEntries() async {
    final cursor = await _getSyncCursor('weight_entries');
    if (cursor == null) {
      await _pullWeightEntriesFull();
    } else {
      await _pullWeightEntriesDelta(cursor);
    }
  }

  Future<void> _pullWeightEntriesFull() async {
    final items = await _getList('/weights');
    final seen = <int>{};
    DateTime? maxUpdatedAt;
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      await _upsertWeightEntry(json);
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    await _deleteMissing('weight_entries', seen);
    if (maxUpdatedAt != null) {
      await _setSyncCursor('weight_entries', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _pullWeightEntriesDelta(DateTime since) async {
    final items = await _getAllPages(
      '/weights',
      size: 200,
      extraQueryParameters: {'updatedSince': since.toUtc().toIso8601String()},
    );
    DateTime? maxUpdatedAt;
    for (final json in items) {
      if (json['deletedAt'] != null) {
        await _deleteWeightEntryTombstone(json['id'] as int);
      } else {
        await _upsertWeightEntry(json);
      }
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    if (maxUpdatedAt != null) {
      await _setSyncCursor('weight_entries', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _upsertWeightEntry(Map<String, dynamic> json) async {
    final serverId = json['id'] as int;
    final existingClientId = await _localClientId('weight_entries', serverId);
    if (existingClientId != null && await _hasPendingOperation(existingClientId)) return;

    final date = DateTime.parse(json['date'] as String);
    final weight = (json['weight'] as num).toDouble();
    if (existingClientId != null) {
      // recordedAt is local-only metadata (when this device first saw the
      // row) — left untouched on update.
      await (_db.update(_db.weightEntries)..where((t) => t.clientId.equals(existingClientId)))
          .write(WeightEntriesCompanion(date: Value(date), weight: Value(weight)));
    } else {
      await _db.into(_db.weightEntries).insert(WeightEntriesCompanion.insert(
            clientId: newClientId(),
            serverId: Value(serverId),
            date: date,
            weight: weight,
            recordedAt: DateTime.now(),
          ));
    }
  }

  Future<void> _deleteWeightEntryTombstone(int serverId) async {
    final clientId = await _localClientId('weight_entries', serverId);
    if (clientId == null) return;
    if (await _hasPendingOperation(clientId)) return;
    await (_db.delete(_db.weightEntries)..where((t) => t.clientId.equals(clientId))).go();
  }

  Future<void> _pullDailySteps() async {
    final cursor = await _getSyncCursor('daily_step_counts');
    if (cursor == null) {
      await _pullDailyStepsFull();
    } else {
      await _pullDailyStepsDelta(cursor);
    }
  }

  Future<void> _pullDailyStepsFull() async {
    final items = await _getList('/steps');
    final seen = <int>{};
    DateTime? maxUpdatedAt;
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      await _upsertDailyStepCount(json);
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    await _deleteMissing('daily_step_counts', seen);
    if (maxUpdatedAt != null) {
      await _setSyncCursor('daily_step_counts', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _pullDailyStepsDelta(DateTime since) async {
    final items = await _getAllPages(
      '/steps',
      size: 200,
      extraQueryParameters: {'updatedSince': since.toUtc().toIso8601String()},
    );
    DateTime? maxUpdatedAt;
    for (final json in items) {
      if (json['deletedAt'] != null) {
        await _deleteDailyStepCountTombstone(json['id'] as int);
      } else {
        await _upsertDailyStepCount(json);
      }
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    if (maxUpdatedAt != null) {
      await _setSyncCursor('daily_step_counts', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _upsertDailyStepCount(Map<String, dynamic> json) async {
    final serverId = json['id'] as int;
    final existingClientId = await _localClientId('daily_step_counts', serverId);
    if (existingClientId != null && await _hasPendingOperation(existingClientId)) return;

    final date = DateTime.parse(json['date'] as String);
    final steps = (json['steps'] as num).toInt();
    if (existingClientId != null) {
      await (_db.update(_db.dailyStepCounts)
            ..where((t) => t.clientId.equals(existingClientId)))
          .write(DailyStepCountsCompanion(
        date: Value(date),
        steps: Value(steps),
      ));
    } else {
      await _db.into(_db.dailyStepCounts).insert(DailyStepCountsCompanion.insert(
            clientId: newClientId(),
            serverId: Value(serverId),
            date: date,
            steps: steps,
          ));
    }
  }

  Future<void> _deleteDailyStepCountTombstone(int serverId) async {
    final clientId = await _localClientId('daily_step_counts', serverId);
    if (clientId == null) return;
    if (await _hasPendingOperation(clientId)) return;
    await (_db.delete(_db.dailyStepCounts)..where((t) => t.clientId.equals(clientId))).go();
  }

  Future<void> _pullWaterEntries() async {
    final cursor = await _getSyncCursor('water_entries');
    if (cursor == null) {
      await _pullWaterEntriesFull();
    } else {
      await _pullWaterEntriesDelta(cursor);
    }
  }

  Future<void> _pullWaterEntriesFull() async {
    final items = await _getList('/water-entries');
    final seen = <int>{};
    DateTime? maxUpdatedAt;
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      await _upsertWaterEntry(json);
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    await _deleteMissing('water_entries', seen);
    if (maxUpdatedAt != null) {
      await _setSyncCursor('water_entries', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _pullWaterEntriesDelta(DateTime since) async {
    final items = await _getAllPages(
      '/water-entries',
      size: 200,
      extraQueryParameters: {'updatedSince': since.toUtc().toIso8601String()},
    );
    DateTime? maxUpdatedAt;
    for (final json in items) {
      if (json['deletedAt'] != null) {
        await _deleteWaterEntryTombstone(json['id'] as int);
      } else {
        await _upsertWaterEntry(json);
      }
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    if (maxUpdatedAt != null) {
      await _setSyncCursor('water_entries', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _upsertWaterEntry(Map<String, dynamic> json) async {
    final serverId = json['id'] as int;
    final existingClientId = await _localClientId('water_entries', serverId);
    if (existingClientId != null && await _hasPendingOperation(existingClientId)) return;

    final sourceServerId = json['sourceId'] as int?;
    final sourceClientId =
        sourceServerId == null ? null : await _localClientId('water_sources', sourceServerId);
    final values = WaterEntriesCompanion(
      sourceClientId: Value(sourceClientId),
      volumeLiters: Value((json['volumeLiters'] as num).toDouble()),
      consumedAt: Value(DateTime.parse(json['consumedAt'] as String)),
    );
    if (existingClientId != null) {
      await (_db.update(_db.waterEntries)..where((t) => t.clientId.equals(existingClientId)))
          .write(values);
    } else {
      await _db.into(_db.waterEntries).insert(
            values.copyWith(clientId: Value(newClientId()), serverId: Value(serverId)),
          );
    }
  }

  Future<void> _deleteWaterEntryTombstone(int serverId) async {
    final clientId = await _localClientId('water_entries', serverId);
    if (clientId == null) return;
    if (await _hasPendingOperation(clientId)) return;
    await (_db.delete(_db.waterEntries)..where((t) => t.clientId.equals(clientId))).go();
  }

  Future<void> _pullSettings() async {
    final response = await _dio.get<Map<String, dynamic>>('/settings');
    final json = response.data;
    if (json == null) return;
    const clientId = 'singleton';
    if (await _hasPendingOperation(clientId)) return;

    await _db.into(_db.userSettingsTable).insertOnConflictUpdate(
          UserSettingsTableCompanion(
            clientId: const Value(clientId),
            unitSystem: Value(json['unitSystem'] as String),
            theme: Value(json['theme'] as String),
            language: Value(json['language'] as String),
            dailyCalorieGoal: Value(json['dailyCalorieGoal'] as int?),
            dailyProteinGoal: Value(json['dailyProteinGoal'] as int?),
            dailyCarbsGoal: Value(json['dailyCarbsGoal'] as int?),
            dailyFatGoal: Value(json['dailyFatGoal'] as int?),
            dailyWaterGoalLiters: Value((json['dailyWaterGoalLiters'] as num?)?.toDouble()),
            dailyStepGoal: Value(json['dailyStepGoal'] as int?),
            workoutReminderEnabled: Value(json['workoutReminderEnabled'] as bool? ?? true),
            trainerCommentPushEnabled: Value(json['trainerCommentPushEnabled'] as bool? ?? true),
            trainerGoalsPushEnabled: Value(json['trainerGoalsPushEnabled'] as bool? ?? true),
            programAssignedPushEnabled: Value(json['programAssignedPushEnabled'] as bool? ?? true),
            restTimerEnabled: Value(json['restTimerEnabled'] as bool? ?? true),
            defaultRestSeconds: Value(json['defaultRestSeconds'] as int? ?? 90),
          ),
        );
  }

  Future<void> _pullWorkoutTemplates() async {
    final cursor = await _getSyncCursor('workout_templates');
    if (cursor == null) {
      await _pullWorkoutTemplatesFull();
    } else {
      await _pullWorkoutTemplatesDelta(cursor);
    }
  }

  Future<void> _pullWorkoutTemplatesFull() async {
    final items = await _getList('/workout-templates');
    final seen = <int>{};
    DateTime? maxUpdatedAt;
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      await _upsertWorkoutTemplate(json);
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    await _deleteMissing(
      'workout_templates',
      seen,
      onDelete: (clientId) => (_db.delete(_db.workoutTemplateExercises)
            ..where((t) => t.templateClientId.equals(clientId)))
          .go(),
    );
    if (maxUpdatedAt != null) {
      await _setSyncCursor('workout_templates', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _pullWorkoutTemplatesDelta(DateTime since) async {
    final items = await _getAllPages(
      '/workout-templates',
      size: 200,
      extraQueryParameters: {'updatedSince': since.toUtc().toIso8601String()},
    );
    DateTime? maxUpdatedAt;
    for (final json in items) {
      if (json['deletedAt'] != null) {
        await _deleteWorkoutTemplateTombstone(json['id'] as int);
      } else {
        await _upsertWorkoutTemplate(json);
      }
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    if (maxUpdatedAt != null) {
      await _setSyncCursor('workout_templates', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  /// Upserts one template row and unconditionally replaces all of its local
  /// exercise links — called from both the full pull (every row, every time)
  /// and the delta pull (every upserted row), per
  /// docs/16-delta-sync-rollout.md §2.3: exercise links are never
  /// independently delta-synced, so any edit to the template — including an
  /// exercise-only edit, since that bumps the template's own `updatedAt` —
  /// must bring a fresh full set of children.
  Future<void> _upsertWorkoutTemplate(Map<String, dynamic> json) async {
    final serverId = json['id'] as int;
    final existingClientId = await _localClientId('workout_templates', serverId);
    if (existingClientId != null && await _hasPendingOperation(existingClientId)) return;

    final clientId = existingClientId ?? newClientId();
    final values = WorkoutTemplatesCompanion(
      name: Value(json['name'] as String),
      originTrainerId: Value(json['originTrainerId'] as int?),
    );
    // BE returns structured exercises: [{exerciseId, targetSets}, ...]
    final entriesJson =
        (json['exercises'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    // Transacted so a crash partway through can't leave this template's
    // row updated but its exercise links deleted-and-not-reinserted.
    await _db.transaction(() async {
      if (existingClientId != null) {
        await (_db.update(_db.workoutTemplates)..where((t) => t.clientId.equals(clientId)))
            .write(values);
      } else {
        await _db.into(_db.workoutTemplates).insert(
              values.copyWith(clientId: Value(clientId), serverId: Value(serverId)),
            );
      }

      await (_db.delete(_db.workoutTemplateExercises)
            ..where((t) => t.templateClientId.equals(clientId)))
          .go();
      for (var i = 0; i < entriesJson.length; i++) {
        final entry = entriesJson[i];
        final exerciseServerId = entry['exerciseId'] as int;
        final exerciseClientId = await _localClientId('exercises', exerciseServerId);
        if (exerciseClientId == null) continue; // dangling ref — exercise not pulled yet
        final targetSets = entry['targetSets'] as int?;
        await _db.into(_db.workoutTemplateExercises).insert(
              WorkoutTemplateExercisesCompanion.insert(
                clientId: newClientId(),
                templateClientId: clientId,
                exerciseClientId: exerciseClientId,
                targetSets: Value(targetSets),
                sortOrder: Value(i),
              ),
            );
      }
    });
  }

  Future<void> _deleteWorkoutTemplateTombstone(int serverId) async {
    final clientId = await _localClientId('workout_templates', serverId);
    if (clientId == null) return;
    if (await _hasPendingOperation(clientId)) return;
    await _db.transaction(() async {
      await (_db.delete(_db.workoutTemplateExercises)
            ..where((t) => t.templateClientId.equals(clientId)))
          .go();
      await (_db.delete(_db.workoutTemplates)..where((t) => t.clientId.equals(clientId))).go();
    });
  }

  Future<void> _pullCardioIntervalPlans() async {
    final cursor = await _getSyncCursor('cardio_interval_plans');
    if (cursor == null) {
      await _pullCardioIntervalPlansFull();
    } else {
      await _pullCardioIntervalPlansDelta(cursor);
    }
  }

  Future<void> _pullCardioIntervalPlansFull() async {
    final items = await _getList('/cardio-interval-plans');
    final seen = <int>{};
    DateTime? maxUpdatedAt;
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      await _upsertCardioIntervalPlan(json);
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    await _deleteMissing(
      'cardio_interval_plans',
      seen,
      onDelete: (clientId) => (_db.delete(_db.cardioIntervalSteps)
            ..where((t) => t.planClientId.equals(clientId)))
          .go(),
    );
    if (maxUpdatedAt != null) {
      await _setSyncCursor('cardio_interval_plans', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _pullCardioIntervalPlansDelta(DateTime since) async {
    final items = await _getAllPages(
      '/cardio-interval-plans',
      size: 200,
      extraQueryParameters: {'updatedSince': since.toUtc().toIso8601String()},
    );
    DateTime? maxUpdatedAt;
    for (final json in items) {
      if (json['deletedAt'] != null) {
        await _deleteCardioIntervalPlanTombstone(json['id'] as int);
      } else {
        await _upsertCardioIntervalPlan(json);
      }
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    if (maxUpdatedAt != null) {
      await _setSyncCursor('cardio_interval_plans', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  /// Upserts one plan row and unconditionally replaces all of its local steps
  /// — called from both the full pull (every row, every time) and the delta
  /// pull (every upserted row), per docs/16-delta-sync-rollout.md §2.3: steps
  /// are never independently delta-synced, so any edit to the plan —
  /// including a step-only edit, since that bumps the plan's own `updatedAt`
  /// — must bring a fresh full set of children.
  Future<void> _upsertCardioIntervalPlan(Map<String, dynamic> json) async {
    final serverId = json['id'] as int;
    final existingClientId = await _localClientId('cardio_interval_plans', serverId);
    if (existingClientId != null && await _hasPendingOperation(existingClientId)) return;

    final clientId = existingClientId ?? newClientId();
    final values = CardioIntervalPlansCompanion(name: Value(json['name'] as String));
    // BE returns the steps as a one-level tree: [{type, name, intensity,
    // durationSeconds, repeatCount, children}, ...]
    final stepsJson = (json['steps'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    // Transacted so a crash partway through can't leave this plan's row
    // updated but its steps deleted-and-not-reinserted.
    await _db.transaction(() async {
      if (existingClientId != null) {
        await (_db.update(_db.cardioIntervalPlans)..where((t) => t.clientId.equals(clientId)))
            .write(values);
      } else {
        await _db.into(_db.cardioIntervalPlans).insert(
              values.copyWith(clientId: Value(clientId), serverId: Value(serverId)),
            );
      }

      await (_db.delete(_db.cardioIntervalSteps)..where((t) => t.planClientId.equals(clientId)))
          .go();
      await _insertCardioIntervalSteps(clientId, stepsJson, null);
    });
  }

  /// Flattens one level of the step tree into rows. `stepIndex` counts per
  /// sibling group (not across the plan), same as the backend stores it.
  Future<void> _insertCardioIntervalSteps(
    String planClientId,
    List<Map<String, dynamic>> steps,
    String? parentStepClientId,
  ) async {
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepClientId = newClientId();
      await _db.into(_db.cardioIntervalSteps).insert(
            CardioIntervalStepsCompanion.insert(
              clientId: stepClientId,
              planClientId: planClientId,
              parentStepClientId: Value(parentStepClientId),
              stepIndex: i,
              stepType: step['type'] as String,
              name: Value(step['name'] as String?),
              intensity: Value(step['intensity'] as String?),
              durationSeconds: Value(step['durationSeconds'] as int?),
              repeatCount: Value(step['repeatCount'] as int?),
            ),
          );
      final children = (step['children'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
      if (children.isNotEmpty) {
        await _insertCardioIntervalSteps(planClientId, children, stepClientId);
      }
    }
  }

  Future<void> _deleteCardioIntervalPlanTombstone(int serverId) async {
    final clientId = await _localClientId('cardio_interval_plans', serverId);
    if (clientId == null) return;
    if (await _hasPendingOperation(clientId)) return;
    await _db.transaction(() async {
      await (_db.delete(_db.cardioIntervalSteps)..where((t) => t.planClientId.equals(clientId)))
          .go();
      await (_db.delete(_db.cardioIntervalPlans)..where((t) => t.clientId.equals(clientId))).go();
    });
  }

  Future<void> _pullWorkoutSessions() async {
    final cursor = await _getSyncCursor('workout_sessions');
    if (cursor == null) {
      await _pullWorkoutSessionsFull();
    } else {
      await _pullWorkoutSessionsDelta(cursor);
    }
  }

  Future<void> _pullWorkoutSessionsFull() async {
    final items = await _getList('/workout-sessions');
    final seen = <int>{};
    DateTime? maxUpdatedAt;
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      await _upsertWorkoutSession(json);
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    await _deleteMissing(
      'workout_sessions',
      seen,
      onDelete: (clientId) async {
        await (_db.delete(_db.workoutSessionExercises)
              ..where((t) => t.sessionClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.exerciseSets)..where((t) => t.sessionClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.cardioDetails)..where((t) => t.sessionClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.cardioSplits)..where((t) => t.sessionClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.cardioWaypoints)..where((t) => t.sessionClientId.equals(clientId)))
            .go();
      },
    );
    if (maxUpdatedAt != null) {
      await _setSyncCursor('workout_sessions', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _pullWorkoutSessionsDelta(DateTime since) async {
    final items = await _getAllPages(
      '/workout-sessions',
      size: 200,
      extraQueryParameters: {'updatedSince': since.toUtc().toIso8601String()},
    );
    DateTime? maxUpdatedAt;
    for (final json in items) {
      if (json['deletedAt'] != null) {
        await _deleteWorkoutSessionTombstone(json['id'] as int);
      } else {
        await _upsertWorkoutSession(json);
      }
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    if (maxUpdatedAt != null) {
      await _setSyncCursor('workout_sessions', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  /// Upserts one session row and unconditionally replaces both of its local
  /// child sets (planned exercises + logged sets) — called from both the
  /// full pull and the delta pull's upsert branch, per
  /// docs/16-delta-sync-rollout.md §2.3: neither child table is independently
  /// delta-synced, so any edit to the session — including a sets-only edit,
  /// since that bumps the session's own `updatedAt` — must bring a fresh full
  /// set of children.
  Future<void> _upsertWorkoutSession(Map<String, dynamic> json) async {
    final serverId = json['id'] as int;
    final existingClientId = await _localClientId('workout_sessions', serverId);
    if (existingClientId != null && await _hasPendingOperation(existingClientId)) return;

    final clientId = existingClientId ?? newClientId();
    final startedRaw = json['startedAt'] as String?;
    final finishedRaw = json['finishedAt'] as String?;
    final scheduledForRaw = json['scheduledFor'] as String?;
    final scheduledTimeRaw = json['scheduledTime'] as String?;
    final templateServerId = json['templateId'] as int?;
    final templateClientId = templateServerId != null
        ? await _localClientId('workout_templates', templateServerId)
        : null;
    final trainerCommentAtRaw = json['trainerCommentAt'] as String?;
    final values = WorkoutSessionsCompanion(
      // Null for a trainer-scheduled session that hasn't been started yet.
      startedAt: Value(startedRaw != null ? DateTime.parse(startedRaw) : null),
      finishedAt: Value(finishedRaw != null ? DateTime.parse(finishedRaw) : null),
      activeCalories: Value((json['activeCalories'] as num?)?.toDouble()),
      averageHeartRate: Value((json['averageHeartRate'] as num?)?.toDouble()),
      healthWorkoutId: Value(json['healthWorkoutId'] as String?),
      templateClientId: Value(templateClientId),
      templateName: Value(json['templateName'] as String?),
      scheduledFor: Value(scheduledForRaw != null ? DateTime.parse(scheduledForRaw) : null),
      scheduledTime: Value(scheduledTimeRaw != null && scheduledTimeRaw.length >= 5
          ? scheduledTimeRaw.substring(0, 5)
          : scheduledTimeRaw),
      scheduleId: Value(json['scheduleId'] as int?),
      rpe: Value(json['rpe'] as int?),
      feedbackNote: Value(json['feedbackNote'] as String?),
      trainerComment: Value(json['trainerComment'] as String?),
      trainerCommentAt:
          Value(trainerCommentAtRaw != null ? DateTime.parse(trainerCommentAtRaw) : null),
      // docs/cardio/53-cardio-mobile-plan.md §1.4: a response is expected to
      // always carry sessionKind now (the backend never omits it, C1.4), but
      // fall back to 'STRENGTH' rather than null for any response that
      // somehow doesn't — this column is NOT NULL locally too.
      sessionKind: Value(json['sessionKind'] as String? ?? 'STRENGTH'),
      activityType: Value(json['activityType'] as String?),
      movingSeconds: Value((json['movingSeconds'] as num?)?.toInt()),
    );
    // Planned exercises, each with the set count the server holds for it.
    // Resolved to local clientIds here, dropping any dangling reference (an
    // exercise this device hasn't pulled — shouldn't happen given [pullAll]'s
    // ordering, but is safely skipped rather than crashing the pull).
    final plannedExercises = <({String exerciseClientId, int? targetSets})>[];
    for (final entry in (json['exercises'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()) {
      final exerciseClientId = await _localClientId('exercises', entry['exerciseId'] as int);
      if (exerciseClientId == null) continue;
      plannedExercises.add((
        exerciseClientId: exerciseClientId,
        targetSets: (entry['targetSets'] as num?)?.toInt(),
      ));
    }
    final setsJson = (json['sets'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    // Transacted so a crash partway through can't leave this session's
    // row updated but its exercise links / sets deleted-and-not-reinserted.
    await _db.transaction(() async {
      if (existingClientId != null) {
        await (_db.update(_db.workoutSessions)..where((t) => t.clientId.equals(clientId)))
            .write(values);
      } else {
        await _db.into(_db.workoutSessions).insert(
              values.copyWith(clientId: Value(clientId), serverId: Value(serverId)),
            );
      }

      // `targetSets` — how many rows (done + still blank) an exercise plans
      // for in this session — is what [LogSessionScreen._rebuildBlocks]
      // derives the blank rows from (`targetSets - doneSets.length`), so a
      // pull that dropped it rebuilt the session with its
      // planned-but-not-yet-logged rows gone.
      //
      // The server now stores and returns it, and its answer wins. This local
      // snapshot is the fallback for the cases where it can't answer: a
      // backend older than the column, and — the common one — a session whose
      // count was already lost by an earlier build of this app and hasn't been
      // re-sent since. Keyed by exerciseClientId (not by position) so a
      // server-side reorder can't misattribute a count; first link wins if a
      // session somehow lists the same exercise twice.
      final preservedTargetSets = <String, int>{};
      for (final link in await (_db.select(_db.workoutSessionExercises)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .get()) {
        final targetSets = link.targetSets;
        if (targetSets != null) {
          preservedTargetSets.putIfAbsent(link.exerciseClientId, () => targetSets);
        }
      }

      await (_db.delete(_db.workoutSessionExercises)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      for (final planned in plannedExercises) {
        await _db.into(_db.workoutSessionExercises).insert(
              WorkoutSessionExercisesCompanion.insert(
                clientId: newClientId(),
                sessionClientId: clientId,
                exerciseClientId: planned.exerciseClientId,
                targetSets: Value(
                    planned.targetSets ?? preservedTargetSets[planned.exerciseClientId]),
              ),
            );
      }

      await (_db.delete(_db.exerciseSets)..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      for (final setJson in setsJson) {
        final exerciseClientId =
            await _localClientId('exercises', setJson['exerciseId'] as int);
        if (exerciseClientId == null) continue; // dangling ref — exercise master row not pulled
        await _db.into(_db.exerciseSets).insert(
              ExerciseSetsCompanion.insert(
                clientId: newClientId(),
                sessionClientId: clientId,
                exerciseClientId: exerciseClientId,
                reps: (setJson['reps'] as num).toInt(),
                weight: (setJson['weight'] as num).toDouble(),
                performedAt: DateTime.parse(setJson['performedAt'] as String),
              ),
            );
      }

      // Cardio metrics + splits — same full-replace model as the two
      // children above (docs/cardio/52-cardio-domain-backend-plan.md §3.3:
      // `cardio`/`splits` are never independently delta-synced, only the
      // parent session is).
      await (_db.delete(_db.cardioDetails)..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      final cardioJson = json['cardio'] as Map<String, dynamic>?;
      if (cardioJson != null) {
        await _db.into(_db.cardioDetails).insert(_cardioDetailsCompanion(clientId, cardioJson));
      }

      await (_db.delete(_db.cardioSplits)..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      final splitsJson =
          (json['splits'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
      for (final splitJson in splitsJson) {
        await _db.into(_db.cardioSplits).insert(_cardioSplitCompanion(clientId, splitJson));
      }

      await (_db.delete(_db.cardioWaypoints)..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      final waypointsJson =
          (json['waypoints'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
      for (final waypointJson in waypointsJson) {
        await _db.into(_db.cardioWaypoints).insert(_cardioWaypointCompanion(clientId, waypointJson));
      }
    });
  }

  /// Field order mirrors the backend's `CardioDetailsResponse` exactly
  /// (docs/cardio/52-cardio-domain-backend-plan.md §3.3).
  CardioDetailsCompanion _cardioDetailsCompanion(
      String sessionClientId, Map<String, dynamic> json) {
    return CardioDetailsCompanion.insert(
      sessionClientId: sessionClientId,
      distanceMeters: Value((json['distanceMeters'] as num?)?.toDouble()),
      elevationGainMeters: Value((json['elevationGainMeters'] as num?)?.toDouble()),
      elevationLossMeters: Value((json['elevationLossMeters'] as num?)?.toDouble()),
      maxAltitudeMeters: Value((json['maxAltitudeMeters'] as num?)?.toDouble()),
      steps: Value((json['steps'] as num?)?.toInt()),
      avgCadence: Value((json['avgCadence'] as num?)?.toDouble()),
      maxCadence: Value((json['maxCadence'] as num?)?.toDouble()),
      best1kSeconds: Value((json['best1kSeconds'] as num?)?.toInt()),
      best5kSeconds: Value((json['best5kSeconds'] as num?)?.toInt()),
      best10kSeconds: Value((json['best10kSeconds'] as num?)?.toInt()),
      avgWatts: Value((json['avgWatts'] as num?)?.toDouble()),
      maxWatts: Value((json['maxWatts'] as num?)?.toDouble()),
      resistanceLevel: Value((json['resistanceLevel'] as num?)?.toInt()),
      deviceCalories: Value((json['deviceCalories'] as num?)?.toDouble()),
      maxHeartRate: Value((json['maxHeartRate'] as num?)?.toDouble()),
      hrZone1Seconds: Value((json['hrZone1Seconds'] as num?)?.toInt()),
      hrZone2Seconds: Value((json['hrZone2Seconds'] as num?)?.toInt()),
      hrZone3Seconds: Value((json['hrZone3Seconds'] as num?)?.toInt()),
      hrZone4Seconds: Value((json['hrZone4Seconds'] as num?)?.toInt()),
      hrZone5Seconds: Value((json['hrZone5Seconds'] as num?)?.toInt()),
      intensity: Value((json['intensity'] as num?)?.toInt()),
      venue: Value(json['venue'] as String?),
      gameFormat: Value(json['gameFormat'] as String?),
      scorePoints: Value((json['scorePoints'] as num?)?.toInt()),
      scoreAssists: Value((json['scoreAssists'] as num?)?.toInt()),
      scoreRebounds: Value((json['scoreRebounds'] as num?)?.toInt()),
      distanceSource: Value(json['distanceSource'] as String?),
      caloriesSource: Value(json['caloriesSource'] as String?),
      routePolyline: Value(json['routePolyline'] as String?),
      routePointCount: Value((json['routePointCount'] as num?)?.toInt()),
      backpackWeightKg: Value((json['backpackWeightKg'] as num?)?.toDouble()),
      weatherCondition: Value(json['weatherCondition'] as String?),
      weatherTempC: Value((json['weatherTempC'] as num?)?.toDouble()),
      weatherWindKph: Value((json['weatherWindKph'] as num?)?.toDouble()),
      weatherPrecipMm: Value((json['weatherPrecipMm'] as num?)?.toDouble()),
    );
  }

  CardioSplitsCompanion _cardioSplitCompanion(String sessionClientId, Map<String, dynamic> json) {
    return CardioSplitsCompanion.insert(
      clientId: newClientId(),
      sessionClientId: sessionClientId,
      splitIndex: (json['splitIndex'] as num).toInt(),
      // Absent on a response that predates intervals — the column's own
      // default says the same thing (docs/cardio/60 C7.1).
      splitType: Value(json['splitType'] as String? ?? 'DISTANCE'),
      distanceMeters: Value((json['distanceMeters'] as num?)?.toDouble()),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      elevationDeltaM: Value((json['elevationDeltaM'] as num?)?.toDouble()),
      avgHeartRate: Value((json['avgHeartRate'] as num?)?.toDouble()),
      avgWatts: Value((json['avgWatts'] as num?)?.toDouble()),
      intensity: Value(json['intensity'] as String?),
    );
  }

  /// Field order mirrors the backend's `CardioWaypointResponse`
  /// (docs/cardio/60 C8.1/C8.4).
  CardioWaypointsCompanion _cardioWaypointCompanion(
      String sessionClientId, Map<String, dynamic> json) {
    return CardioWaypointsCompanion.insert(
      clientId: newClientId(),
      sessionClientId: sessionClientId,
      waypointIndex: (json['waypointIndex'] as num).toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitudeMeters: Value((json['altitudeMeters'] as num?)?.toDouble()),
      label: Value(json['label'] as String?),
    );
  }

  Future<void> _deleteWorkoutSessionTombstone(int serverId) async {
    final clientId = await _localClientId('workout_sessions', serverId);
    if (clientId == null) return;
    if (await _hasPendingOperation(clientId)) return;
    await _db.transaction(() async {
      await (_db.delete(_db.workoutSessionExercises)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      await (_db.delete(_db.exerciseSets)..where((t) => t.sessionClientId.equals(clientId))).go();
      await (_db.delete(_db.cardioDetails)..where((t) => t.sessionClientId.equals(clientId))).go();
      await (_db.delete(_db.cardioSplits)..where((t) => t.sessionClientId.equals(clientId))).go();
      await (_db.delete(_db.cardioWaypoints)..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      await (_db.delete(_db.workoutSessions)..where((t) => t.clientId.equals(clientId))).go();
    });
  }

  Future<void> _pullRecipes() async {
    final cursor = await _getSyncCursor('recipes');
    if (cursor == null) {
      await _pullRecipesFull();
    } else {
      await _pullRecipesDelta(cursor);
    }
  }

  Future<void> _pullRecipesFull() async {
    final items = await _getList('/recipes');
    final seen = <int>{};
    DateTime? maxUpdatedAt;
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      await _upsertRecipe(json);
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    await _deleteMissing(
      'recipes',
      seen,
      onDelete: (clientId) =>
          (_db.delete(_db.recipeIngredients)..where((t) => t.recipeClientId.equals(clientId)))
              .go(),
    );
    if (maxUpdatedAt != null) {
      await _setSyncCursor('recipes', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _pullRecipesDelta(DateTime since) async {
    final items = await _getAllPages(
      '/recipes',
      size: 200,
      extraQueryParameters: {'updatedSince': since.toUtc().toIso8601String()},
    );
    DateTime? maxUpdatedAt;
    for (final json in items) {
      if (json['deletedAt'] != null) {
        await _deleteRecipeTombstone(json['id'] as int);
      } else {
        await _upsertRecipe(json);
      }
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    if (maxUpdatedAt != null) {
      await _setSyncCursor('recipes', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  /// Upserts one recipe row and unconditionally replaces all of its local
  /// ingredients — called from both the full pull and the delta pull's
  /// upsert branch, per docs/16-delta-sync-rollout.md §2.3: ingredients are
  /// never independently delta-synced, so any edit to the recipe — including
  /// an ingredient-only edit, since that bumps the recipe's own `updatedAt` —
  /// must bring a fresh full set of children.
  Future<void> _upsertRecipe(Map<String, dynamic> json) async {
    final serverId = json['id'] as int;
    final existingClientId = await _localClientId('recipes', serverId);
    if (existingClientId != null && await _hasPendingOperation(existingClientId)) return;

    final clientId = existingClientId ?? newClientId();
    final imageUpdatedAtRaw = json['imageUpdatedAt'] as String?;
    final values = RecipesCompanion(
      name: Value(json['name'] as String),
      description: Value(json['description'] as String?),
      favorite: Value(json['favorite'] as bool? ?? false),
      servings: Value(json['servings'] as int? ?? 1),
      originTrainerId: Value(json['originTrainerId'] as int?),
      imageUpdatedAt:
          Value(imageUpdatedAtRaw != null ? DateTime.parse(imageUpdatedAtRaw) : null),
    );
    final ingredientsJson =
        (json['ingredients'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    // Transacted so a crash partway through (e.g. a malformed later
    // ingredient) can't leave this recipe's row updated but its
    // ingredients deleted-and-not-reinserted.
    await _db.transaction(() async {
      if (existingClientId != null) {
        await (_db.update(_db.recipes)..where((t) => t.clientId.equals(clientId)))
            .write(values);
      } else {
        await _db.into(_db.recipes).insert(
              values.copyWith(clientId: Value(clientId), serverId: Value(serverId)),
            );
      }

      await (_db.delete(_db.recipeIngredients)..where((t) => t.recipeClientId.equals(clientId)))
          .go();
      for (final ingredient in ingredientsJson) {
        final foodClientId = await _localClientId('foods', ingredient['foodId'] as int);
        if (foodClientId == null) continue; // dangling ref — food master row not pulled
        await _db.into(_db.recipeIngredients).insert(
              RecipeIngredientsCompanion.insert(
                clientId: newClientId(),
                recipeClientId: clientId,
                foodClientId: foodClientId,
                quantityInGrams: (ingredient['quantityInGrams'] as num).toDouble(),
              ),
            );
      }
    });
  }

  Future<void> _deleteRecipeTombstone(int serverId) async {
    final clientId = await _localClientId('recipes', serverId);
    if (clientId == null) return;
    if (await _hasPendingOperation(clientId)) return;
    await _db.transaction(() async {
      await (_db.delete(_db.recipeIngredients)..where((t) => t.recipeClientId.equals(clientId)))
          .go();
      await (_db.delete(_db.recipes)..where((t) => t.clientId.equals(clientId))).go();
    });
  }

  Future<void> _pullMeals() async {
    final cursor = await _getSyncCursor('meals');
    if (cursor == null) {
      await _pullMealsFull();
    } else {
      await _pullMealsDelta(cursor);
    }
  }

  Future<void> _pullMealsFull() async {
    final items = await _getList('/meals');
    final seen = <int>{};
    DateTime? maxUpdatedAt;
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      await _upsertMeal(json);
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    await _deleteMissing(
      'meals',
      seen,
      onDelete: (clientId) =>
          (_db.delete(_db.mealEntries)..where((t) => t.mealClientId.equals(clientId))).go(),
    );
    if (maxUpdatedAt != null) {
      await _setSyncCursor('meals', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  Future<void> _pullMealsDelta(DateTime since) async {
    final items = await _getAllPages(
      '/meals',
      size: 200,
      extraQueryParameters: {'updatedSince': since.toUtc().toIso8601String()},
    );
    DateTime? maxUpdatedAt;
    for (final json in items) {
      if (json['deletedAt'] != null) {
        await _deleteMealTombstone(json['id'] as int);
      } else {
        await _upsertMeal(json);
      }
      maxUpdatedAt = _maxUpdatedAt(maxUpdatedAt, json);
    }
    if (maxUpdatedAt != null) {
      await _setSyncCursor('meals', maxUpdatedAt.subtract(_cursorOverlap));
    }
  }

  /// Upserts one meal row and unconditionally replaces all of its local
  /// entries — called from both the full pull and the delta pull's upsert
  /// branch, per docs/16-delta-sync-rollout.md §2.3: entries are never
  /// independently delta-synced, so any edit to the meal — including an
  /// entry-only edit (grams changed, food swapped), since that bumps the
  /// meal's own `updatedAt` — must bring a fresh full set of entries.
  Future<void> _upsertMeal(Map<String, dynamic> json) async {
    final serverId = json['id'] as int;
    final existingClientId = await _localClientId('meals', serverId);
    if (existingClientId != null && await _hasPendingOperation(existingClientId)) return;

    final clientId = existingClientId ?? newClientId();
    final values = MealsCompanion(
      mealDateTime: Value(DateTime.parse(json['dateTime'] as String)),
      mealType: Value(json['mealType'] as String),
      name: Value(json['name'] as String?),
    );
    final entriesJson =
        (json['entries'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    // Transacted so a crash partway through (e.g. a malformed later
    // entry) can't leave this meal's row updated but its entries
    // deleted-and-not-reinserted.
    await _db.transaction(() async {
      if (existingClientId != null) {
        await (_db.update(_db.meals)..where((t) => t.clientId.equals(clientId))).write(values);
      } else {
        await _db.into(_db.meals).insert(
              values.copyWith(clientId: Value(clientId), serverId: Value(serverId)),
            );
      }

      await (_db.delete(_db.mealEntries)..where((t) => t.mealClientId.equals(clientId))).go();
      for (final entry in entriesJson) {
        final foodServerId = entry['foodId'] as int;
        var foodClientId = await _localClientId('foods', foodServerId);
        // Hidden foods (quick-macro entries) are not returned by GET /foods,
        // so they can be missing from the local cache. Fetch the individual
        // food via GET /foods/{id} and store it locally so the meal entry
        // can reference it.
        foodClientId ??= await _fetchAndStoreFood(foodServerId);
        if (foodClientId == null) continue; // still not found — skip entry
        await _db.into(_db.mealEntries).insert(
              MealEntriesCompanion.insert(
                clientId: newClientId(),
                mealClientId: clientId,
                foodClientId: foodClientId,
                quantityInGrams: (entry['quantityInGrams'] as num).toDouble(),
              ),
            );
      }
    });
  }

  Future<void> _deleteMealTombstone(int serverId) async {
    final clientId = await _localClientId('meals', serverId);
    if (clientId == null) return;
    if (await _hasPendingOperation(clientId)) return;
    await _db.transaction(() async {
      await (_db.delete(_db.mealEntries)..where((t) => t.mealClientId.equals(clientId))).go();
      await (_db.delete(_db.meals)..where((t) => t.clientId.equals(clientId))).go();
    });
  }

  Future<List<Map<String, dynamic>>> _getList(String basePath) async {
    final response = await _dio.get<List<dynamic>>(basePath);
    return (response.data ?? const []).cast<Map<String, dynamic>>();
  }

  /// Fetches every page of a `page`/`size`-pageable endpoint (see
  /// docs/05-backend-api.md — the pageable+searchable pattern introduced for
  /// Foods) and returns the concatenated `content` across all pages, looping
  /// until the server reports `last: true`. This only chunks the transfer —
  /// callers still get the full result set, same as [_getList], so switching
  /// a `_pull*` method from [_getList] to this one changes nothing about what
  /// ends up in the local table, only how many requests it takes to get there.
  Future<List<Map<String, dynamic>>> _getAllPages(
    String basePath, {
    int size = 200,
    Map<String, dynamic>? extraQueryParameters,
  }) async {
    final items = <Map<String, dynamic>>[];
    var page = 0;
    while (true) {
      final response = await _dio.get<Map<String, dynamic>>(
        basePath,
        queryParameters: {
          'page': page,
          'size': size,
          ...?extraQueryParameters,
        },
      );
      final json = response.data;
      if (json == null) break;
      final content = (json['content'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
      items.addAll(content);
      if ((json['last'] as bool? ?? true) || content.isEmpty) break;
      page++;
    }
    return items;
  }

  Future<String?> _localClientId(String table, int serverId) async {
    // LIMIT 1 + take-first rather than getSingleOrNull: if a prior interrupted
    // or concurrent pull ever left two local rows sharing one server_id,
    // getSingleOrNull throws "Too many elements", which would abort the whole
    // entity pull. Tolerate the duplicate here (any matching clientId is fine
    // for the lookup) instead of crashing the refresh.
    final rows = await _db
        .customSelect(
          'SELECT client_id FROM $table WHERE server_id = ? LIMIT 1',
          variables: [Variable.withInt(serverId)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.read<String>('client_id');
  }

  /// True if [clientId] has a local edit that still needs to reach the
  /// server: queued (`pending`/`syncing`), or failed for a reason that will
  /// resolve itself (a network blip, retried automatically by [SyncEngine]).
  /// A non-network `failed` row never retries on its own, so it must NOT
  /// block the pull — otherwise the local row (which may hold a broken
  /// optimistic write from the failed edit) would diverge from the server's
  /// truth forever.
  Future<bool> _hasPendingOperation(String clientId) async {
    // A clientId can legitimately have more than one pending row (e.g. a
    // create plus a queued update against it — see OutboxWriter.enqueueUpdate),
    // so query ALL of them: getSingleOrNull would throw "Too many elements"
    // and abort the entire pull. Block server-overwrite if any row is still
    // queued (pending/syncing) or failed for a network reason that retries on
    // its own; a non-network failure never retries, so it must not block.
    final rows = await (_db.select(_db.pendingOperations)
          ..where((t) => t.clientId.equals(clientId)))
        .get();
    for (final row in rows) {
      if (row.status == 'failed') {
        if (row.lastError?.startsWith('[network] ') ?? false) return true;
      } else {
        return true;
      }
    }
    return false;
  }

  /// Fetches a single food by server id and stores it locally. Used to recover
  /// hidden foods (quick-macro entries) that are absent from the GET /foods
  /// list response but are still referenced by meal entries. Returns the new
  /// local clientId on success, or null if the server returns 404 or errors.
  Future<String?> _fetchAndStoreFood(int serverId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/foods/$serverId');
      final json = response.data;
      if (json == null) return null;
      final clientId = newClientId();
      await _db.into(_db.foods).insert(FoodsCompanion.insert(
            clientId: clientId,
            serverId: Value(serverId),
            name: json['name'] as String,
            caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
            proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
            carbsPer100g: Value((json['carbsPer100g'] as num?)?.toDouble()),
            fatPer100g: Value((json['fatPer100g'] as num?)?.toDouble()),
            barcode: Value(json['barcode'] as String?),
            hidden: Value(json['hidden'] as bool? ?? true),
            originTrainerId: Value(json['originTrainerId'] as int?),
          ));
      return clientId;
    } catch (_) {
      return null;
    }
  }

  /// Deletes local rows in [table] whose serverId no longer appears in this
  /// pull's [seenServerIds] (removed server-side, or by another device) and
  /// have no pending operation of their own. [onDelete] runs first so
  /// callers can clean up child rows before the parent disappears.
  ///
  /// [additionalWhere] is appended verbatim to the WHERE clause (e.g.
  /// `"AND hidden = false"`) so callers can exclude rows the server never
  /// returns — hidden foods are the canonical case: they are created locally
  /// and synced up, but the backend's GET /foods endpoint omits them, so
  /// without the filter they would be deleted on every pull.
  Future<void> _deleteMissing(
    String table,
    Set<int> seenServerIds, {
    Future<void> Function(String clientId)? onDelete,
    String additionalWhere = '',
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT client_id, server_id FROM $table WHERE server_id IS NOT NULL $additionalWhere',
        )
        .get();
    for (final row in rows) {
      final serverId = row.read<int>('server_id');
      if (seenServerIds.contains(serverId)) continue;
      final clientId = row.read<String>('client_id');
      if (await _hasPendingOperation(clientId)) continue;
      if (onDelete != null) await onDelete(clientId);
      await _db.customStatement('DELETE FROM $table WHERE client_id = ?', [clientId]);
      // customStatement doesn't notify watchers of the table it deleted from,
      // so without this the row lingers in every watch stream's last emitted
      // value (resurfacing as a stale empty row) until an unrelated write
      // re-queries it. See SyncEngine._applySuccess for the same fix.
      _db.notifyUpdates({TableUpdate(table, kind: UpdateKind.delete)});
    }
  }
}

final pullEngineProvider = Provider<PullEngine>((ref) {
  return PullEngine(
    ref.watch(appDatabaseProvider),
    ref.watch(dioClientProvider),
    ref.watch(syncLockProvider),
  );
});

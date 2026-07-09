import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local_db/app_database.dart';
import '../local_db/database_provider.dart';
import '../network/dio_client.dart';
import 'client_id.dart';

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
  PullEngine(this._db, this._dio);

  final AppDatabase _db;
  final Dio _dio;

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
      // Order matters: entities referenced by others (as a clientId lookup)
      // are pulled first.
      //
      // Each entity is pulled in its own guard so a failure in one — a
      // malformed payload, an unexpected null, or a duplicate-serverId
      // collision that makes `getSingleOrNull()` throw — can't abort the
      // whole refresh and leave every *later* entity (water, steps, meals…)
      // stale. The failing entity keeps its last-known local state and is
      // retried on the next pull; the rest still refresh. Without this, the
      // first throwing entity (foods) silently stops the entire sync — the
      // only network call that goes out is its GET.
      await _guard('foods', _pullFoods);
      await _guard('exercises', _pullExercises);
      await _guard('water_sources', _pullWaterSources);
      await _guard('weight_entries', _pullWeightEntries);
      await _guard('water_entries', _pullWaterEntries);
      await _guard('daily_steps', _pullDailySteps);
      await _guard('settings', _pullSettings);
      await _guard('workout_templates', _pullWorkoutTemplates);
      await _guard('workout_sessions', _pullWorkoutSessions);
      await _guard('recipes', _pullRecipes);
      await _guard('meals', _pullMeals);
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
    );
    final plannedExerciseIds = await _mapServerIds(
      'exercises',
      ((json['exercises'] as List<dynamic>? ?? const []))
          .map((e) => (e as Map<String, dynamic>)['exerciseId'] as int)
          .toList(),
    );
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

      await (_db.delete(_db.workoutSessionExercises)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      for (final exerciseClientId in plannedExerciseIds) {
        await _db.into(_db.workoutSessionExercises).insert(
              WorkoutSessionExercisesCompanion.insert(
                clientId: newClientId(),
                sessionClientId: clientId,
                exerciseClientId: exerciseClientId,
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
    });
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
    final values = RecipesCompanion(
      name: Value(json['name'] as String),
      description: Value(json['description'] as String?),
      favorite: Value(json['favorite'] as bool? ?? false),
      servings: Value(json['servings'] as int? ?? 1),
      originTrainerId: Value(json['originTrainerId'] as int?),
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

  /// Maps a list of server ids in [table] to their local clientIds, in
  /// order, dropping any that aren't known locally (a dangling reference to
  /// an entity that hasn't been pulled — shouldn't happen given [pullAll]'s
  /// ordering, but is safely skipped rather than crashing the pull).
  Future<List<String>> _mapServerIds(String table, List<int> serverIds) async {
    final clientIds = <String>[];
    for (final serverId in serverIds) {
      final clientId = await _localClientId(table, serverId);
      if (clientId != null) clientIds.add(clientId);
    }
    return clientIds;
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
  return PullEngine(ref.watch(appDatabaseProvider), ref.watch(dioClientProvider));
});

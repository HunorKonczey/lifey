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
    } catch (e, st) {
      debugPrint('PullEngine: $entity FAILED, continuing: $e\n$st');
    }
  }

  Future<void> _pullFoods() async {
    final items = await _getList('/foods');
    final seen = <int>{};
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      final existingClientId = await _localClientId('foods', serverId);
      if (existingClientId != null && await _hasPendingOperation(existingClientId)) continue;

      final values = FoodsCompanion(
        name: Value(json['name'] as String),
        caloriesPer100g: Value((json['caloriesPer100g'] as num).toDouble()),
        proteinPer100g: Value((json['proteinPer100g'] as num).toDouble()),
        carbsPer100g: Value((json['carbsPer100g'] as num?)?.toDouble()),
        fatPer100g: Value((json['fatPer100g'] as num?)?.toDouble()),
        barcode: Value(json['barcode'] as String?),
        hidden: Value(json['hidden'] as bool? ?? false),
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
    await _deleteMissing('foods', seen, additionalWhere: 'AND hidden = false');
  }

  Future<void> _pullExercises() async {
    final items = await _getList('/exercises');
    final seen = <int>{};
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      final existingClientId = await _localClientId('exercises', serverId);
      if (existingClientId != null && await _hasPendingOperation(existingClientId)) continue;

      final values = ExercisesCompanion(
        name: Value(json['name'] as String),
        category: Value(json['category'] as String?),
        equipment: Value(json['equipment'] as String?),
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
    await _deleteMissing('exercises', seen);
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
    final items = await _getList('/weights');
    final seen = <int>{};
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      final existingClientId = await _localClientId('weight_entries', serverId);
      if (existingClientId != null && await _hasPendingOperation(existingClientId)) continue;

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
    await _deleteMissing('weight_entries', seen);
  }

  Future<void> _pullDailySteps() async {
    final items = await _getList('/steps');
    final seen = <int>{};
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      final existingClientId = await _localClientId('daily_step_counts', serverId);
      if (existingClientId != null && await _hasPendingOperation(existingClientId)) continue;

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
    await _deleteMissing('daily_step_counts', seen);
  }

  Future<void> _pullWaterEntries() async {
    final items = await _getList('/water-entries');
    final seen = <int>{};
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      final existingClientId = await _localClientId('water_entries', serverId);
      if (existingClientId != null && await _hasPendingOperation(existingClientId)) continue;

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
    await _deleteMissing('water_entries', seen);
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
    final items = await _getList('/workout-templates');
    final seen = <int>{};
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      final existingClientId = await _localClientId('workout_templates', serverId);
      if (existingClientId != null && await _hasPendingOperation(existingClientId)) continue;

      final clientId = existingClientId ?? newClientId();
      final values = WorkoutTemplatesCompanion(name: Value(json['name'] as String));
      // BE now returns structured exercises: [{exerciseId, targetSets}, ...]
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
    await _deleteMissing(
      'workout_templates',
      seen,
      onDelete: (clientId) => (_db.delete(_db.workoutTemplateExercises)
            ..where((t) => t.templateClientId.equals(clientId)))
          .go(),
    );
  }

  Future<void> _pullWorkoutSessions() async {
    final items = await _getList('/workout-sessions');
    final seen = <int>{};
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      final existingClientId = await _localClientId('workout_sessions', serverId);
      if (existingClientId != null && await _hasPendingOperation(existingClientId)) continue;

      final clientId = existingClientId ?? newClientId();
      final finishedRaw = json['finishedAt'] as String?;
      final templateServerId = json['templateId'] as int?;
      final templateClientId = templateServerId != null
          ? await _localClientId('workout_templates', templateServerId)
          : null;
      final values = WorkoutSessionsCompanion(
        startedAt: Value(DateTime.parse(json['startedAt'] as String)),
        finishedAt: Value(finishedRaw != null ? DateTime.parse(finishedRaw) : null),
        activeCalories: Value((json['activeCalories'] as num?)?.toDouble()),
        averageHeartRate: Value((json['averageHeartRate'] as num?)?.toDouble()),
        healthWorkoutId: Value(json['healthWorkoutId'] as String?),
        templateClientId: Value(templateClientId),
        templateName: Value(json['templateName'] as String?),
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
  }

  Future<void> _pullRecipes() async {
    final items = await _getList('/recipes');
    final seen = <int>{};
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      final existingClientId = await _localClientId('recipes', serverId);
      if (existingClientId != null && await _hasPendingOperation(existingClientId)) continue;

      final clientId = existingClientId ?? newClientId();
      final values = RecipesCompanion(
        name: Value(json['name'] as String),
        description: Value(json['description'] as String?),
        favorite: Value(json['favorite'] as bool? ?? false),
        servings: Value(json['servings'] as int? ?? 1),
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
    await _deleteMissing(
      'recipes',
      seen,
      onDelete: (clientId) =>
          (_db.delete(_db.recipeIngredients)..where((t) => t.recipeClientId.equals(clientId)))
              .go(),
    );
  }

  Future<void> _pullMeals() async {
    final items = await _getList('/meals');
    final seen = <int>{};
    for (final json in items) {
      final serverId = json['id'] as int;
      seen.add(serverId);
      final existingClientId = await _localClientId('meals', serverId);
      if (existingClientId != null && await _hasPendingOperation(existingClientId)) continue;

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
          if (foodClientId == null) {
            foodClientId = await _fetchAndStoreFood(foodServerId);
          }
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
    await _deleteMissing(
      'meals',
      seen,
      onDelete: (clientId) =>
          (_db.delete(_db.mealEntries)..where((t) => t.mealClientId.equals(clientId))).go(),
    );
  }

  Future<List<Map<String, dynamic>>> _getList(String basePath) async {
    final response = await _dio.get<List<dynamic>>(basePath);
    return (response.data ?? const []).cast<Map<String, dynamic>>();
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

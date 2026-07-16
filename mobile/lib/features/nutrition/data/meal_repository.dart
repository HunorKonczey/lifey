import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/daily_macros.dart';
import '../domain/food_usage.dart';
import '../domain/meal.dart';

typedef _JoinedMealRow = TypedResult;

/// How far back meal history counts toward [MealRepository.watchFoodUsage],
/// so long-abandoned eating habits stop influencing suggestion ranking.
const _usageWindow = Duration(days: 90);

/// One food + quantity to include when logging a meal (request side).
class MealEntryInput {
  const MealEntryInput({required this.foodClientId, required this.grams});

  final String foodClientId;
  final double grams;
}

/// Local-first access to meals and their entries. A meal and its entries are
/// always written together (see [create]/[update]), so watching just the
/// `meals` table is enough to catch every change to the whole aggregate.
class MealRepository {
  MealRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  // meals, mealEntries and foods are joined into a *single* SQL query so
  // Drift re-runs them as one atomic read. Watching those three tables
  // separately and combining the results in Dart (as this used to do) means
  // each table's watch stream re-queries and emits independently — when
  // delete() removes a meal's entries and then the meal row itself in the
  // same transaction, the mealEntries$ update can arrive before meals$'s
  // does, and the combined snapshot briefly (or, if meals$ is slow,
  // indefinitely) shows the meal still present but with zero entries/macros.
  // A join can't produce that inconsistent state: it's computed in one shot
  // against a single consistent read of the database.
  //
  // pendingOperations is still combined separately — it's only used for the
  // delete-block filter and never written in the same transaction as
  // meals/mealEntries, so there's no equivalent race for it.
  Stream<List<Meal>> watchAll() {
    final joinedMeals$ = _db.select(_db.meals).join([
      leftOuterJoin(_db.mealEntries, _db.mealEntries.mealClientId.equalsExp(_db.meals.clientId)),
      leftOuterJoin(_db.foods, _db.foods.clientId.equalsExp(_db.mealEntries.foodClientId)),
    ]).watch();

    return combineLatest2(
      joinedMeals$,
      _db.select(_db.pendingOperations).watch(),
      _processJoined,
    );
  }

  /// Like [watchAll] but bounded to the most recent [limit] meals (by date).
  /// The pending-delete filter can drop rows below the requested limit, so
  /// callers that need to know whether more rows exist beyond [limit] should
  /// request `limit + 1` and treat a returned list longer than the intended
  /// page size as "more available".
  ///
  /// Limiting can't be applied directly to the meals+entries+foods join
  /// (a row-level SQL LIMIT there would cut off mid-meal once a meal has
  /// several entries, capping joined rows rather than distinct meals). So
  /// this first picks the page's meal ids with a plain limited query, then
  /// re-joins scoped to just those ids — switching to a fresh join whenever
  /// the id set changes (e.g. a new meal enters the window).
  Stream<List<Meal>> watchPaged({required int limit}) {
    final pageIds$ = (_db.select(_db.meals)
          ..orderBy([(t) => OrderingTerm.desc(t.mealDateTime)])
          ..limit(limit))
        .watch()
        .map((rows) => rows.map((r) => r.clientId).toList());

    return switchMap(pageIds$, (ids) {
      if (ids.isEmpty) {
        return Stream.value(const <Meal>[]);
      }
      final joinedMeals$ = (_db.select(_db.meals)..where((t) => t.clientId.isIn(ids))).join([
        leftOuterJoin(_db.mealEntries, _db.mealEntries.mealClientId.equalsExp(_db.meals.clientId)),
        leftOuterJoin(_db.foods, _db.foods.clientId.equalsExp(_db.mealEntries.foodClientId)),
      ]).watch();

      return combineLatest2(
        joinedMeals$,
        _db.select(_db.pendingOperations).watch(),
        _processJoined,
      );
    });
  }

  List<Meal> _processJoined(List<_JoinedMealRow> joinedRows, List<PendingOperationRow> ops) {
    final blocked = blockedByActiveDelete(ops);

    final mealRowsByClientId = <String, MealRow>{};
    final entriesByMeal = <String, List<MealEntry>>{};
    for (final row in joinedRows) {
      final mealRow = row.readTable(_db.meals);
      if (blocked.contains(mealRow.clientId)) continue;
      mealRowsByClientId[mealRow.clientId] = mealRow;

      final entryRow = row.readTableOrNull(_db.mealEntries);
      if (entryRow == null) continue; // meal has no entries — left join produced no match

      final food = row.readTableOrNull(_db.foods);
      final grams = entryRow.quantityInGrams;
      entriesByMeal.putIfAbsent(mealRow.clientId, () => []).add(
            MealEntry(
              foodClientId: entryRow.foodClientId,
              foodName: food?.name ?? 'Unknown',
              quantityInGrams: grams,
              calories: (food?.caloriesPer100g ?? 0) * grams / 100,
              protein: (food?.proteinPer100g ?? 0) * grams / 100,
              carbs: (food?.carbsPer100g ?? 0) * grams / 100,
              fat: (food?.fatPer100g ?? 0) * grams / 100,
            ),
          );
    }

    final meals = mealRowsByClientId.values
        .map((row) => _toDomain(row, entriesByMeal[row.clientId] ?? const []))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return meals;
  }

  /// Full-history per-day macro totals, unpaged and unbounded — unlike
  /// [watchPaged]'s UI window, every day back to account creation is
  /// included. Needed for streaks/weekly recap to be accurate over months of
  /// history (see docs/37-streaks-weekly-recap-plan.md), which the old
  /// approach of aggregating [watchPaged]'s 40-meal window could not do.
  ///
  /// Sums come from a slim projection of the join — [mealDateTime],
  /// [quantityInGrams] and the food's per-100g macros — rather than building
  /// a full [Meal]/[MealEntry] domain object per entry, so materializing
  /// years of history doesn't hold onto more than the numbers needed for a
  /// running total.
  ///
  /// Bucketed by *local* calendar day in Dart, not SQL: [mealDateTime] is
  /// stored as a UTC instant, and grouping in SQL would bucket by UTC day
  /// boundaries instead of the device's local day, silently misplacing
  /// meals logged near midnight.
  ///
  /// A meal with no entries still creates its day's bucket (at zero) via the
  /// left join, matching "a meal was logged that day" even when it has no
  /// entries yet — the shape the calorie streak's "day counts only if
  /// something was logged" rule needs.
  Stream<List<DailyMacros>> watchDailyMacros() {
    final joined$ = _db.select(_db.meals).join([
      leftOuterJoin(_db.mealEntries, _db.mealEntries.mealClientId.equalsExp(_db.meals.clientId)),
      leftOuterJoin(_db.foods, _db.foods.clientId.equalsExp(_db.mealEntries.foodClientId)),
    ]).watch();

    return combineLatest2(joined$, _db.select(_db.pendingOperations).watch(), _aggregateDaily);
  }

  List<DailyMacros> _aggregateDaily(
    List<_JoinedMealRow> joinedRows,
    List<PendingOperationRow> ops,
  ) {
    final blocked = blockedByActiveDelete(ops);
    final byDay = <DateTime, _DailyAccumulator>{};

    for (final row in joinedRows) {
      final meal = row.readTable(_db.meals);
      if (blocked.contains(meal.clientId)) continue;

      final local = meal.mealDateTime.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final acc = byDay.putIfAbsent(day, () => _DailyAccumulator());

      final entry = row.readTableOrNull(_db.mealEntries);
      if (entry == null) continue; // meal has no entries — left join produced no match

      final food = row.readTableOrNull(_db.foods);
      final grams = entry.quantityInGrams;
      acc.add(
        calories: (food?.caloriesPer100g ?? 0) * grams / 100,
        protein: (food?.proteinPer100g ?? 0) * grams / 100,
        carbs: (food?.carbsPer100g ?? 0) * grams / 100,
        fat: (food?.fatPer100g ?? 0) * grams / 100,
      );
    }

    final result = byDay.entries
        .map((e) => DailyMacros(
              day: e.key,
              calories: e.value.calories,
              protein: e.value.protein,
              carbs: e.value.carbs,
              fat: e.value.fat,
            ))
        .toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    return result;
  }

  /// Per-food usage stats over the last [_usageWindow] of meal history,
  /// keyed by `foodClientId`. Pending deletes are not filtered out here —
  /// the stats are a ranking heuristic, and a meal awaiting delete
  /// confirmation still describes what the user actually ate.
  Stream<Map<String, FoodUsage>> watchFoodUsage() {
    final cutoff = DateTime.now().subtract(_usageWindow);
    final joined$ = (_db.select(_db.mealEntries).join([
      innerJoin(_db.meals, _db.meals.clientId.equalsExp(_db.mealEntries.mealClientId)),
    ])..where(_db.meals.mealDateTime.isBiggerOrEqualValue(cutoff)))
        .watch();

    return joined$.map((rows) {
      final usage = <String, FoodUsage>{};
      for (final row in rows) {
        final entry = row.readTable(_db.mealEntries);
        final meal = row.readTable(_db.meals);
        final prev = usage[entry.foodClientId];
        final isNewest = prev == null || meal.mealDateTime.isAfter(prev.lastUsedAt);
        usage[entry.foodClientId] = FoodUsage(
          lastUsedAt: isNewest ? meal.mealDateTime : prev.lastUsedAt,
          useCount: (prev?.useCount ?? 0) + 1,
          lastGrams: isNewest ? entry.quantityInGrams : prev.lastGrams,
        );
      }
      return usage;
    });
  }

  /// One-shot fetch of meals logged in the last [days] calendar days,
  /// today inclusive — used by "copy a previous day" to build per-day
  /// summaries without holding a live subscription. Bounding by a lower time
  /// cutoff (rather than by row count, like [watchPaged]) guarantees every
  /// recent day is fully represented regardless of how many meals were
  /// logged on any single day.
  Future<List<Meal>> recentMeals({required int days}) async {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final joinedRows = await (_db.select(_db.meals)
          ..where((t) => t.mealDateTime.isBiggerOrEqualValue(cutoff)))
        .join([
          leftOuterJoin(_db.mealEntries, _db.mealEntries.mealClientId.equalsExp(_db.meals.clientId)),
          leftOuterJoin(_db.foods, _db.foods.clientId.equalsExp(_db.mealEntries.foodClientId)),
        ])
        .get();
    final ops = await _db.select(_db.pendingOperations).get();
    return _processJoined(joinedRows, ops);
  }

  Future<String> create({
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
    String? name,
  }) async {
    final clientId = newClientId();
    await _db.transaction(() async {
      await _db.into(_db.meals).insert(
            MealsCompanion.insert(
              clientId: clientId,
              mealDateTime: dateTime,
              mealType: mealType.apiValue,
              name: Value(name),
            ),
          );
      await _insertEntries(clientId, entries);
    });
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'meal',
      payload: _payload(dateTime: dateTime, mealType: mealType, entries: entries, name: name),
    );
    return clientId;
  }

  Future<void> update(
    String clientId, {
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
    String? name,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.meals)..where((t) => t.clientId.equals(clientId))).write(
        MealsCompanion(
          mealDateTime: Value(dateTime),
          mealType: Value(mealType.apiValue),
          name: Value(name),
        ),
      );
      await (_db.delete(_db.mealEntries)..where((t) => t.mealClientId.equals(clientId))).go();
      await _insertEntries(clientId, entries);
    });
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'meal',
      payload: _payload(dateTime: dateTime, mealType: mealType, entries: entries, name: name),
    );
  }

  Future<void> delete(String clientId) async {
    // Must enqueue before the local row is gone — enqueueDelete needs to
    // read its serverId while the row still exists. If it queued a server
    // delete, the meal and its entries stay (hidden by the controller's
    // filter) until that delete is confirmed — see
    // EntitySyncConfig.cleanupChildren's doc.
    final queued = await _outbox.enqueueDelete(clientId: clientId, entityType: 'meal');
    if (!queued) {
      await _db.transaction(() async {
        await (_db.delete(_db.mealEntries)..where((t) => t.mealClientId.equals(clientId))).go();
        await (_db.delete(_db.meals)..where((t) => t.clientId.equals(clientId))).go();
      });
    }
  }

  Future<void> _insertEntries(String mealClientId, List<MealEntryInput> entries) async {
    for (final entry in entries) {
      await _db.into(_db.mealEntries).insert(
            MealEntriesCompanion.insert(
              clientId: newClientId(),
              mealClientId: mealClientId,
              foodClientId: entry.foodClientId,
              quantityInGrams: entry.grams,
            ),
          );
    }
  }

  Map<String, dynamic> _payload({
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
    String? name,
  }) {
    return {
      'dateTime': dateTime.toUtc().toIso8601String(),
      'mealType': mealType.apiValue,
      if (name != null) 'name': name,
      'entries': entries
          .map((e) => {'foodId': clientRef(e.foodClientId), 'quantityInGrams': e.grams})
          .toList(),
    };
  }

  Meal _toDomain(MealRow row, List<MealEntry> entries) {
    return Meal(
      clientId: row.clientId,
      id: row.serverId,
      dateTime: row.mealDateTime,
      mealType: MealType.fromApi(row.mealType),
      name: row.name,
      entries: entries,
    );
  }
}

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});

class _DailyAccumulator {
  double calories = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;

  void add({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    this.calories += calories;
    this.protein += protein;
    this.carbs += carbs;
    this.fat += fat;
  }
}

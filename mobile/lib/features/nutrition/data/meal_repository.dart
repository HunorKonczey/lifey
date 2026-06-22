import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/meal.dart';

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
      (rows, ops) => (rows, ops),
    ).map((pair) {
      final (joinedRows, ops) = pair;
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
    });
  }

  Future<void> create({
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
  }) async {
    final clientId = newClientId();
    await _db.transaction(() async {
      await _db.into(_db.meals).insert(
            MealsCompanion.insert(
              clientId: clientId,
              mealDateTime: dateTime,
              mealType: mealType.apiValue,
            ),
          );
      await _insertEntries(clientId, entries);
    });
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'meal',
      payload: _payload(dateTime: dateTime, mealType: mealType, entries: entries),
    );
  }

  Future<void> update(
    String clientId, {
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.meals)..where((t) => t.clientId.equals(clientId))).write(
        MealsCompanion(mealDateTime: Value(dateTime), mealType: Value(mealType.apiValue)),
      );
      await (_db.delete(_db.mealEntries)..where((t) => t.mealClientId.equals(clientId))).go();
      await _insertEntries(clientId, entries);
    });
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'meal',
      payload: _payload(dateTime: dateTime, mealType: mealType, entries: entries),
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
  }) {
    return {
      'dateTime': dateTime.toUtc().toIso8601String(),
      'mealType': mealType.apiValue,
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
      entries: entries,
    );
  }
}

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});

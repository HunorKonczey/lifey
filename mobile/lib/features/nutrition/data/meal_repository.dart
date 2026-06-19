import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
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

  // Backend expects a LocalDateTime, i.e. an ISO string without a zone.
  static final _dateTimeFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  Stream<List<Meal>> watchAll() {
    return _db.select(_db.meals).watch().asyncMap((mealRows) async {
      if (mealRows.isEmpty) return const <Meal>[];

      final foods = {for (final f in await _db.select(_db.foods).get()) f.clientId: f};

      final entriesByMeal = <String, List<MealEntry>>{};
      for (final entry in await _db.select(_db.mealEntries).get()) {
        final food = foods[entry.foodClientId];
        final grams = entry.quantityInGrams;
        entriesByMeal.putIfAbsent(entry.mealClientId, () => []).add(
              MealEntry(
                foodClientId: entry.foodClientId,
                foodName: food?.name ?? 'Unknown',
                quantityInGrams: grams,
                calories: (food?.caloriesPer100g ?? 0) * grams / 100,
                protein: (food?.proteinPer100g ?? 0) * grams / 100,
                carbs: (food?.carbsPer100g ?? 0) * grams / 100,
                fat: (food?.fatPer100g ?? 0) * grams / 100,
              ),
            );
      }

      final meals = mealRows
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
    await _db.transaction(() async {
      await (_db.delete(_db.mealEntries)..where((t) => t.mealClientId.equals(clientId))).go();
      await (_db.delete(_db.meals)..where((t) => t.clientId.equals(clientId))).go();
    });
    await _outbox.enqueueDelete(clientId: clientId, entityType: 'meal');
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
      'dateTime': _dateTimeFormat.format(dateTime),
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

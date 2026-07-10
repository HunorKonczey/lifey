import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/nutrition/data/meal_repository.dart';

void main() {
  late AppDatabase db;
  late MealRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // watchFoodUsage never writes, so the outbox (and its sync engine) is a
    // constructor requirement only — the Dio instance is never called.
    repo = MealRepository(db, OutboxWriter(db, SyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<void> insertMeal(String clientId, DateTime dateTime,
      {required Map<String, double> gramsByFood}) async {
    await db.into(db.meals).insert(MealsCompanion.insert(
          clientId: clientId,
          mealDateTime: dateTime,
          mealType: 'LUNCH',
        ));
    var i = 0;
    for (final entry in gramsByFood.entries) {
      await db.into(db.mealEntries).insert(MealEntriesCompanion.insert(
            clientId: '$clientId-e${i++}',
            mealClientId: clientId,
            foodClientId: entry.key,
            quantityInGrams: entry.value,
          ));
    }
  }

  test('aggregates count, last-used time and last grams per food', () async {
    // Truncated to whole seconds — drift persists DateTime as unix seconds,
    // so sub-second precision would not round-trip.
    final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000);
    await insertMeal('m1', now.subtract(const Duration(days: 2)),
        gramsByFood: {'chicken': 150, 'rice': 80});
    await insertMeal('m2', now.subtract(const Duration(days: 1)),
        gramsByFood: {'chicken': 200});

    final usage = await repo.watchFoodUsage().first;

    expect(usage, hasLength(2));
    expect(usage['chicken']!.useCount, 2);
    expect(usage['chicken']!.lastGrams, 200);
    expect(usage['chicken']!.lastUsedAt, now.subtract(const Duration(days: 1)));
    expect(usage['rice']!.useCount, 1);
    expect(usage['rice']!.lastGrams, 80);
  });

  test('lastGrams comes from the newest meal regardless of insert order', () async {
    final now = DateTime.now();
    // Newest meal inserted first — aggregation must key on mealDateTime,
    // not row order.
    await insertMeal('m-new', now, gramsByFood: {'oats': 60});
    await insertMeal('m-old', now.subtract(const Duration(days: 5)),
        gramsByFood: {'oats': 90});

    final usage = await repo.watchFoodUsage().first;

    expect(usage['oats']!.useCount, 2);
    expect(usage['oats']!.lastGrams, 60);
  });

  test('ignores meals older than the 90-day window', () async {
    final now = DateTime.now();
    await insertMeal('m-ancient', now.subtract(const Duration(days: 120)),
        gramsByFood: {'cake': 100});
    await insertMeal('m-recent', now.subtract(const Duration(days: 3)),
        gramsByFood: {'chicken': 150});

    final usage = await repo.watchFoodUsage().first;

    expect(usage.keys, ['chicken']);
  });

  test('emits an empty map with no meal history', () async {
    final usage = await repo.watchFoodUsage().first;
    expect(usage, isEmpty);
  });
}

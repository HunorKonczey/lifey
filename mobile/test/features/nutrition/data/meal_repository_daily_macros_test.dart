import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
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
    repo = MealRepository(db, OutboxWriter(db, SyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<void> insertFood(
    String clientId, {
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
  }) {
    return db.into(db.foods).insert(FoodsCompanion.insert(
          clientId: clientId,
          name: clientId,
          caloriesPer100g: calories,
          proteinPer100g: protein,
          carbsPer100g: Value(carbs),
          fatPer100g: Value(fat),
        ));
  }

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

  DateTime localDay(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  test('sums macros across meals on the same local day', () async {
    await insertFood('chicken', calories: 200, protein: 30, carbs: 0, fat: 5);
    final now = DateTime.now();
    final morning = DateTime(now.year, now.month, now.day, 8);
    final evening = DateTime(now.year, now.month, now.day, 19);

    await insertMeal('m1', morning, gramsByFood: {'chicken': 100});
    await insertMeal('m2', evening, gramsByFood: {'chicken': 200});

    final days = await repo.watchDailyMacros().first;

    expect(days, hasLength(1));
    expect(days.single.day, localDay(now));
    expect(days.single.calories, 600); // 200 + 400
    expect(days.single.protein, 90); // 30 + 60
    expect(days.single.fat, 15); // 5 + 10
  });

  test('buckets meals from different days separately, newest first', () async {
    await insertFood('rice', calories: 130, protein: 3);
    final now = DateTime.now();
    await insertMeal('m-today', now, gramsByFood: {'rice': 100});
    await insertMeal('m-yesterday', now.subtract(const Duration(days: 1)),
        gramsByFood: {'rice': 200});

    final days = await repo.watchDailyMacros().first;

    expect(days, hasLength(2));
    expect(days.first.day, localDay(now));
    expect(days.first.calories, 130);
    expect(days.last.day, localDay(now.subtract(const Duration(days: 1))));
    expect(days.last.calories, 260);
  });

  test('a meal with no entries still creates a zero-total day bucket', () async {
    final now = DateTime.now();
    await insertMeal('m-empty', now, gramsByFood: const {});

    final days = await repo.watchDailyMacros().first;

    expect(days, hasLength(1));
    expect(days.single.day, localDay(now));
    expect(days.single.calories, 0);
  });

  test('treats a missing carbs/fat value as zero', () async {
    await insertFood('protein-shake', calories: 120, protein: 25);
    final now = DateTime.now();
    await insertMeal('m1', now, gramsByFood: {'protein-shake': 100});

    final days = await repo.watchDailyMacros().first;

    expect(days.single.carbs, 0);
    expect(days.single.fat, 0);
  });

  test('emits an empty list with no meal history', () async {
    final days = await repo.watchDailyMacros().first;
    expect(days, isEmpty);
  });
}

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/nutrition/data/meal_repository.dart';

/// LIF-148: a logged entry carries its food's fibre and sugar scaled to the grams - null when the food has no figure, which is
/// not the same as 0.
void main() {
  late AppDatabase db;
  late MealRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MealRepository(db, OutboxWriter(db, SyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<void> food(String id, {double? fiber, double? sugar}) => db.into(db.foods).insert(FoodsCompanion.insert(
        clientId: id,
        name: id,
        caloriesPer100g: 100,
        proteinPer100g: 5,
        fiberPer100g: Value(fiber),
        sugarPer100g: Value(sugar),
      ));

  test('entries get the figures scaled to their grams; a food without them gets null, not 0', () async {
    await food('oats', fiber: 10, sugar: 1);
    await food('mystery');
    final now = DateTime.now();
    await db.into(db.meals).insert(MealsCompanion.insert(clientId: 'm', mealDateTime: now, mealType: 'LUNCH'));
    await db.into(db.mealEntries).insert(MealEntriesCompanion.insert(clientId: 'e1', mealClientId: 'm', foodClientId: 'oats', quantityInGrams: 50));
    await db.into(db.mealEntries).insert(MealEntriesCompanion.insert(clientId: 'e2', mealClientId: 'm', foodClientId: 'mystery', quantityInGrams: 200));

    final meal = (await repo.watchAll().first).single;

    final oats = meal.entries.firstWhere((e) => e.foodClientId == 'oats');
    expect(oats.fiber, 5);
    expect(oats.sugar, 0.5);
    final mystery = meal.entries.firstWhere((e) => e.foodClientId == 'mystery');
    expect(mystery.fiber, isNull);
    expect(mystery.sugar, isNull);

    expect(meal.fiberSugar.fiber, 5);
    expect(meal.fiberSugar.sugar, 0.5);
    expect(meal.fiberSugar.partial, isTrue);
  });
}

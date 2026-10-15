import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/network/dio_client.dart';
import 'package:lifey/core/sync/client_ref.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/core/sync/sync_engine_provider.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/data/meal_repository.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

/// docs/88: an entry added as part of a recipe remembers it - through the local store, the push payload, an edit, a
/// duplicate and a copy of the day. Any of them rebuilding the entries without the tag silently forgets it.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late MealRepository repo;
  late MealController controller;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio();
    container = ProviderContainer(overrides: [
      dioClientProvider.overrideWithValue(dio),
      appDatabaseProvider.overrideWithValue(db),
      syncEngineProvider.overrideWith((ref) => _NoopSyncEngine(db, dio)),
    ]);
    repo = container.read(mealRepositoryProvider);
    controller = container.read(mealControllerProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> food(String id) => db.into(db.foods).insert(FoodsCompanion.insert(
        clientId: id,
        name: id,
        caloriesPer100g: 100,
        proteinPer100g: 5,
      ));

  Future<Meal> only() async => (await repo.watchAll().first).single;

  Future<Map<String, dynamic>> pushedPayload() async {
    final op = await db.select(db.pendingOperations).getSingle();
    return jsonDecode(op.payloadJson) as Map<String, dynamic>;
  }

  List<MealEntryInput> mixed() => const [
        MealEntryInput(foodClientId: 'beans', grams: 100, recipeClientId: 'chilli'),
        MealEntryInput(foodClientId: 'salad', grams: 50),
      ];

  test('a tagged entry is stored and read back, an untagged one stays untagged', () async {
    await food('beans');
    await food('salad');

    await repo.create(dateTime: DateTime.now(), mealType: MealType.lunch, entries: mixed());

    final entries = (await only()).entries;
    expect(entries.firstWhere((e) => e.foodClientId == 'beans').recipeClientId, 'chilli');
    expect(entries.firstWhere((e) => e.foodClientId == 'salad').recipeClientId, isNull);
  });

  test('the push sends the tag as an optional reference, and omits it for an untagged entry', () async {
    await food('beans');
    await food('salad');

    await repo.create(dateTime: DateTime.now(), mealType: MealType.lunch, entries: mixed());

    final entries = ((await pushedPayload())['entries'] as List).cast<Map<String, dynamic>>();
    final beans = entries.firstWhere((e) => e['foodId'] == clientRef('beans'));
    final salad = entries.firstWhere((e) => e['foodId'] == clientRef('salad'));
    expect(beans['recipeId'], optionalClientRef('chilli'));
    expect(isOptionalClientRef(beans['recipeId']), isTrue);
    expect(salad.containsKey('recipeId'), isFalse);
  });

  test('an update that passes the tags on keeps them, and one that drops them clears them', () async {
    await food('beans');
    await food('salad');
    final id = await repo.create(dateTime: DateTime.now(), mealType: MealType.lunch, entries: mixed());

    await repo.update(id, dateTime: DateTime.now(), mealType: MealType.lunch, entries: mixed());
    expect((await only()).entries.map((e) => e.recipeClientId), unorderedEquals(['chilli', null]));

    await repo.update(
      id,
      dateTime: DateTime.now(),
      mealType: MealType.lunch,
      entries: const [MealEntryInput(foodClientId: 'beans', grams: 100)],
    );
    expect((await only()).entries.single.recipeClientId, isNull);
  });

  group('copies of a meal', () {
    test('duplicating a meal keeps the tags', () async {
      await food('beans');
      await food('salad');
      final id = await repo.create(dateTime: DateTime.now(), mealType: MealType.lunch, entries: mixed());
      final meal = (await repo.watchAll().first).firstWhere((m) => m.clientId == id);

      final copy = await controller.duplicateMeal(meal);

      expect(copy.entries.map((e) => e.recipeClientId), unorderedEquals(['chilli', null]));
      final stored = (await repo.watchAll().first).firstWhere((m) => m.clientId == copy.clientId);
      expect(stored.entries.map((e) => e.recipeClientId), unorderedEquals(['chilli', null]));
    });

    test('copying a day keeps the tags', () async {
      await food('beans');
      await food('salad');
      final id = await repo.create(dateTime: DateTime.now(), mealType: MealType.lunch, entries: mixed());
      final meal = (await repo.watchAll().first).firstWhere((m) => m.clientId == id);
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      expect(await controller.copyMeals([meal], tomorrow), 1);

      final copies = (await repo.watchAll().first).where((m) => m.clientId != id).toList();
      expect(copies.single.entries.map((e) => e.recipeClientId), unorderedEquals(['chilli', null]));
    });
  });
}

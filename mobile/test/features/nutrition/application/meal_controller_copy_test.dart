import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/network/dio_client.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/core/sync/sync_engine_provider.dart';
import 'package:lifey/features/nutrition/application/food_controller.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/data/meal_repository.dart';
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';

/// [OutboxWriter] fires a fire-and-forget `sync()` on every write (production
/// behavior — queued writes go out without the caller waiting on the
/// network). In a test, that background kick can still be mid-flight when
/// `tearDown` closes the in-memory database, and drift then reports a
/// spurious "test failed after it had already completed". A no-op engine
/// (matching test/core/sync/food_update_http_method_test.dart's pattern)
/// keeps these tests deterministic without changing what's under test —
/// none of them assert on server sync.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

/// Never actually invoked — sync is stubbed out via [_NoopSyncEngine] below
/// — but Dio requires some adapter to be set.
class _FakeAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'id': 1}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late ProviderContainer container;
  late MealRepository repo;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = _FakeAdapter();
    final db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      dioClientProvider.overrideWithValue(dio),
      appDatabaseProvider.overrideWithValue(db),
      syncEngineProvider.overrideWith((ref) => _NoopSyncEngine(db, dio)),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);
    repo = container.read(mealRepositoryProvider);
  });

  // MealController's mutation methods only ever `ref.read` the repository —
  // they don't depend on the provider's bridged watch stream being actively
  // listened to — so `.notifier` alone is enough here; no need to also
  // subscribe to `mealControllerProvider` itself.
  MealController notifier() => container.read(mealControllerProvider.notifier);

  Future<Food> makeFood(String name) => container.read(foodControllerProvider.notifier).addFood(
        name: name,
        calories: 200,
        protein: 20,
      );

  test('duplicateMeal creates a copy logged now, returned directly', () async {
    final food = await makeFood('Chicken');
    final originalId = await notifier().logMeal(
      dateTime: DateTime.now().subtract(const Duration(days: 3)),
      mealType: MealType.breakfast,
      name: 'Old breakfast',
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 150)],
    );
    final original =
        (await repo.recentMeals(days: 5)).firstWhere((m) => m.clientId == originalId);

    final duplicated = await notifier().duplicateMeal(original);

    expect(duplicated.clientId, isNot(originalId));
    expect(duplicated.mealType, MealType.breakfast);
    expect(duplicated.name, 'Old breakfast');
    expect(duplicated.entries.single.foodClientId, food.clientId);
    expect(duplicated.entries.single.quantityInGrams, 150);
    final now = DateTime.now();
    final local = duplicated.dateTime.toLocal();
    expect((local.year, local.month, local.day), (now.year, now.month, now.day));

    // Persisted, not just an in-memory preview.
    final all = await repo.recentMeals(days: 5);
    expect(all.map((m) => m.clientId), contains(duplicated.clientId));
  });

  test('copyMeals preserves time-of-day and appends to a target day with existing meals', () async {
    final food = await makeFood('Rice');
    final sourceDay = DateTime.now().subtract(const Duration(days: 2));
    final sourceTime = DateTime(sourceDay.year, sourceDay.month, sourceDay.day, 13, 30);
    await notifier().logMeal(
      dateTime: sourceTime,
      mealType: MealType.lunch,
      name: 'Lunch',
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 200)],
    );
    final today = DateTime.now();
    await notifier().logMeal(
      dateTime: today,
      mealType: MealType.snack,
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 30)],
    );

    final sourceMeals =
        (await repo.recentMeals(days: 5)).where((m) => m.mealType == MealType.lunch).toList();
    final copied = await notifier().copyMeals(sourceMeals, today);

    expect(copied, 1);
    final all = await repo.recentMeals(days: 5);
    // Appended, not replaced — the pre-existing snack on today is still there.
    expect(all.where((m) => m.mealType == MealType.snack), hasLength(1));
    final copiedMeal =
        all.firstWhere((m) => m.mealType == MealType.lunch && m.dateTime != sourceTime);
    final local = copiedMeal.dateTime.toLocal();
    expect((local.year, local.month, local.day), (today.year, today.month, today.day));
    expect(local.hour, 13);
    expect(local.minute, 30);
    expect(copiedMeal.entries.single.quantityInGrams, 200);
  });

  test('copyMeals skips a source meal with no entries and returns the true count copied', () async {
    final food = await makeFood('Eggs');
    await notifier().logMeal(
      dateTime: DateTime.now(),
      mealType: MealType.breakfast,
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 100)],
    );
    final withEntries = (await repo.recentMeals(days: 1)).single;
    final entryless = Meal(
      clientId: 'phantom',
      dateTime: DateTime.now(),
      mealType: MealType.snack,
      entries: const [],
    );

    final copied = await notifier().copyMeals([withEntries, entryless], DateTime.now());

    expect(copied, 1);
  });

  test('recentMeals excludes meals older than the requested window', () async {
    final food = await makeFood('Toast');
    await notifier().logMeal(
      dateTime: DateTime.now().subtract(const Duration(days: 10)),
      mealType: MealType.breakfast,
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 50)],
    );
    await notifier().logMeal(
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      mealType: MealType.breakfast,
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 50)],
    );

    final recent = await notifier().recentMeals(days: 3);

    expect(recent, hasLength(1));
  });
}

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/nutrition/presentation/meals_tab.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/date_range_filter_bar.dart';

/// See test/core/sync/food_update_http_method_test.dart's comment — the
/// outbox's fire-and-forget kick can otherwise race the test's DB teardown.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream,
      Future<void>? cancelFuture) {
    throw UnimplementedError('never called — sync is a no-op in this test');
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = _FailingAdapter();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      dioClientProvider.overrideWithValue(dio),
      syncEngineProvider.overrideWith((ref) => _NoopSyncEngine(db, dio)),
    ]);
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Future<void> pumpMealsTab(WidgetTester tester) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MealsTab(filter: DateRangeFilter.today)),
        ),
      ),
    );
  }

  testWidgets('offers "Copy yesterday" when today is empty but yesterday has meals', (tester) async {
    final food = await container
        .read(foodControllerProvider.notifier)
        .addFood(name: 'Yogurt', calories: 120, protein: 10);
    await container.read(mealControllerProvider.notifier).logMeal(
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      mealType: MealType.breakfast,
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 100)],
    );

    await pumpMealsTab(tester);
    await tester.pumpAndSettle();

    expect(find.text('Copy yesterday'), findsOneWidget);
  });

  testWidgets('does not offer "Copy yesterday" when yesterday has no meals either', (tester) async {
    await pumpMealsTab(tester);
    await tester.pumpAndSettle();

    expect(find.text('Copy yesterday'), findsNothing);
  });

  testWidgets('tapping "Copy yesterday" logs a meal for today and shows the count', (tester) async {
    final food = await container
        .read(foodControllerProvider.notifier)
        .addFood(name: 'Yogurt', calories: 120, protein: 10);
    await container.read(mealControllerProvider.notifier).logMeal(
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      mealType: MealType.breakfast,
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 100)],
    );

    await pumpMealsTab(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy yesterday'));
    await tester.pumpAndSettle();

    expect(find.text('1 meal copied'), findsOneWidget);
    // The tab now shows a meal for today instead of the empty state.
    expect(find.text('Copy yesterday'), findsNothing);
  });
}

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
import 'package:lifey/features/nutrition/domain/day_meals_summary.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/nutrition/presentation/widgets/copy_day_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

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

/// Opens [CopyDaySheet] and, if given, taps [tapAfterOpen] once the sheet
/// has loaded — used to pick a day row and let the resulting pop resolve.
Future<DayMealsSummary?> _pumpSheet(
  WidgetTester tester,
  ProviderContainer container, {
  bool hasMealsToday = false,
  Finder? tapAfterOpen,
}) {
  return tester.runAsync<DayMealsSummary?>(() async {
    DayMealsSummary? result;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<DayMealsSummary>(
                    context: context,
                    builder: (_) => CopyDaySheet(hasMealsToday: hasMealsToday),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (tapAfterOpen != null) {
      await tester.tap(tapAfterOpen);
      await tester.pumpAndSettle();
    }
    return result;
  });
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

  testWidgets('shows the last 7 days with meals, excluding today', (tester) async {
    final food = await container
        .read(foodControllerProvider.notifier)
        .addFood(name: 'Rice', calories: 130, protein: 3);
    final notifier = container.read(mealControllerProvider.notifier);
    // 100g @ 130 kcal/100g = 130 kcal.
    await notifier.logMeal(
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      mealType: MealType.lunch,
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 100)],
    );
    // 150g @ 130 kcal/100g = 195 kcal.
    await notifier.logMeal(
      dateTime: DateTime.now().subtract(const Duration(days: 3)),
      mealType: MealType.dinner,
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 150)],
    );
    // Today's own meal must never appear as a "copy from" source.
    await notifier.logMeal(
      dateTime: DateTime.now(),
      mealType: MealType.breakfast,
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 50)],
    );

    await _pumpSheet(tester, container);

    expect(find.text('1 meal · 130 kcal'), findsOneWidget);
    expect(find.text('1 meal · 195 kcal'), findsOneWidget);
  });

  testWidgets('shows an empty message when no recent day has meals', (tester) async {
    await container.read(foodControllerProvider.notifier).addFood(
        name: 'Unused', calories: 100, protein: 5); // seed the DB without any meal

    await _pumpSheet(tester, container);

    expect(find.text('No meals in the last week'), findsOneWidget);
  });

  testWidgets('shows the appends-to-today note only when today already has meals', (tester) async {
    final food = await container
        .read(foodControllerProvider.notifier)
        .addFood(name: 'Oats', calories: 90, protein: 4);
    await container.read(mealControllerProvider.notifier).logMeal(
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      mealType: MealType.lunch,
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 100)],
    );

    await _pumpSheet(tester, container, hasMealsToday: true);
    expect(find.text("Adds to today's existing meals"), findsOneWidget);
  });

  testWidgets('tapping a day pops the sheet with that day\'s summary', (tester) async {
    final food = await container
        .read(foodControllerProvider.notifier)
        .addFood(name: 'Bread', calories: 250, protein: 8);
    await container.read(mealControllerProvider.notifier).logMeal(
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      mealType: MealType.lunch,
      entries: [MealEntryInput(foodClientId: food.clientId, grams: 100)],
    );

    final picked = await _pumpSheet(tester, container, tapAfterOpen: find.text('1 meal · 250 kcal'));

    expect(picked, isNotNull);
    expect(picked!.mealCount, 1);
  });
}

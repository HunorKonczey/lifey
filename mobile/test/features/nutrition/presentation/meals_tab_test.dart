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
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/nutrition/application/food_controller.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/application/selected_meal_day_provider.dart';
import 'package:lifey/features/nutrition/data/meal_repository.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/nutrition/presentation/meals_tab.dart';
import 'package:lifey/features/nutrition/presentation/widgets/meal_list_row.dart';
import 'package:lifey/features/nutrition/presentation/widgets/week_strip.dart';
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
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
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

  Future<void> pumpMealsTab(WidgetTester tester, {VoidCallback? onCopyDay}) async {
    tester.view.physicalSize = const Size(411 * 2.625, 923 * 2.625);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MealsTab(onCopyDay: onCopyDay)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> logMeal(DateTime at, MealType type, {String food = 'Yogurt', double grams = 100, String? name}) async {
    final existing = container.read(foodControllerProvider).value?.where((f) => f.name == food);
    final item = (existing != null && existing.isNotEmpty)
        ? existing.first
        : await container.read(foodControllerProvider.notifier).addFood(name: food, calories: 120, protein: 10);
    await container.read(mealControllerProvider.notifier).logMeal(
      dateTime: at,
      mealType: type,
      name: name,
      entries: [MealEntryInput(foodClientId: item.clientId, grams: grams)],
    );
  }

  DateTime today(int hour) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, hour);
  }

  DateTime daysAgo(int days, int hour) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day - days, hour);
  }

  testWidgets('an empty today shows the empty state with "Add meal" and "Copy a day"', (tester) async {
    var copies = 0;
    await pumpMealsTab(tester, onCopyDay: () => copies++);

    expect(find.text('No meals yet today'), findsOneWidget);
    expect(find.text('Add meal'), findsOneWidget);
    await tester.tap(find.text('Copy a day'));
    expect(copies, 1);
    // The week strip and the budget are there even without meals.
    expect(find.byType(WeekStrip), findsOneWidget);
    expect(find.textContaining('kcal'), findsWidgets);
  });

  testWidgets("today's meals are one grouped list in time order, with the budget above", (tester) async {
    await logMeal(today(7), MealType.breakfast, name: 'Oats & berries');
    await logMeal(today(8), MealType.snack, food: 'Apple', grams: 200);
    await pumpMealsTab(tester);

    expect(find.byType(MealListRow), findsNWidgets(2));
    expect(find.text('Oats & berries'), findsOneWidget);
    expect(find.text('Snack'), findsOneWidget);
    final rows = tester.widgetList<MealListRow>(find.byType(MealListRow)).toList();
    expect(rows.first.meal.mealType, MealType.breakfast); // 07:00 before 08:00
    expect(find.text('No meals yet today'), findsNothing);
  });

  testWidgets('selecting an earlier day shows that day\'s meals and hides today\'s', (tester) async {
    await logMeal(today(7), MealType.breakfast, name: 'Todays porridge');
    await logMeal(daysAgo(2, 13), MealType.lunch, name: 'Old pasta');
    await pumpMealsTab(tester);
    expect(find.text('Todays porridge'), findsOneWidget);

    final target = daysAgo(2, 0);
    await tester.tap(find.descendant(of: find.byType(WeekStrip), matching: find.text('${target.day}')));
    await tester.pumpAndSettle();

    expect(find.text('Old pasta'), findsOneWidget);
    expect(find.text('Todays porridge'), findsNothing);
    expect(container.read(selectedMealDayProvider), target);
  });

  testWidgets('an earlier day without meals says so and offers only "Add meal"', (tester) async {
    await logMeal(today(7), MealType.breakfast);
    await pumpMealsTab(tester, onCopyDay: () {});

    final target = daysAgo(3, 0);
    await tester.tap(find.descendant(of: find.byType(WeekStrip), matching: find.text('${target.day}')));
    await tester.pumpAndSettle();

    expect(find.text('No meals on this day'), findsOneWidget);
    expect(find.text('Add meal'), findsOneWidget);
    expect(find.text('Copy a day'), findsNothing);
  });

  testWidgets('long-press opens the meal menu: Edit, Duplicate, Delete', (tester) async {
    await logMeal(today(7), MealType.breakfast, name: 'Oats & berries');
    await pumpMealsTab(tester);

    await tester.longPress(find.text('Oats & berries'));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Delete in the menu asks first, then removes the meal', (tester) async {
    await logMeal(today(7), MealType.breakfast, name: 'Oats & berries');
    await pumpMealsTab(tester);

    await tester.longPress(find.text('Oats & berries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // The confirmation.
    expect(find.text('Oats & berries'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Oats & berries'), findsNothing);
    expect(find.text('No meals yet today'), findsOneWidget);
  });

  testWidgets('Duplicate in the menu opens the date dialog', (tester) async {
    await logMeal(today(7), MealType.breakfast, name: 'Oats & berries');
    await pumpMealsTab(tester);

    await tester.longPress(find.text('Oats & berries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Duplicate'), findsOneWidget);
  });
}

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/ads/interstitial_manager.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/network/dio_client.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/core/sync/sync_engine_provider.dart';
import 'package:lifey/features/nutrition/application/food_controller.dart';
import 'package:lifey/features/nutrition/application/remaining_budget_provider.dart';
import 'package:lifey/features/nutrition/domain/remaining_budget.dart';
import 'package:lifey/features/nutrition/presentation/foods_tab.dart';
import 'package:lifey/features/nutrition/presentation/log_meal_screen.dart';
import 'package:lifey/features/nutrition/presentation/widgets/add_food_sheet.dart';
import 'package:lifey/features/nutrition/presentation/widgets/add_meal_entry_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// See meals_tab_copy_yesterday_test.dart — keeps the outbox kick from racing
/// the in-memory DB teardown.
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

class _NoAds extends InterstitialManager {
  _NoAds(super.ref);

  @override
  Future<void> maybeShow(BuildContext context, InterstitialReason reason) async {}
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
      interstitialManagerProvider.overrideWith(_NoAds.new),
      remainingBudgetProvider.overrideWithValue(const AsyncValue<RemainingBudget>.loading()),
    ]);
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Future<void> pumpFoodsTab(WidgetTester tester, {String? searchQuery}) async {
    await container
        .read(foodControllerProvider.notifier)
        .addFood(name: 'Yogurt', calories: 120, protein: 10);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FoodsTab(searchQuery: searchQuery)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder addToMealButton() => find.byTooltip('Add to meal');

  testWidgets('the add-to-meal button opens a new meal on that food', (tester) async {
    await pumpFoodsTab(tester);

    await tester.tap(addToMealButton());
    await tester.pumpAndSettle();

    expect(find.byType(LogMealScreen), findsOneWidget);
    expect(find.byType(AddMealEntrySheet), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Yogurt'), findsOneWidget);
  });

  testWidgets('works from search results too', (tester) async {
    await pumpFoodsTab(tester, searchQuery: 'yog');

    await tester.tap(addToMealButton());
    await tester.pumpAndSettle();

    expect(find.byType(LogMealScreen), findsOneWidget);
  });

  testWidgets('a double tap opens only one meal screen', (tester) async {
    await pumpFoodsTab(tester);

    await tester.tap(addToMealButton());
    await tester.tap(addToMealButton(), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(LogMealScreen), findsOneWidget);
  });

  testWidgets('tapping the card body still opens the food editor', (tester) async {
    await pumpFoodsTab(tester);

    await tester.tap(find.text('Yogurt'));
    await tester.pumpAndSettle();

    expect(find.byType(AddFoodSheet), findsOneWidget);
    expect(find.byType(LogMealScreen), findsNothing);
  });
}

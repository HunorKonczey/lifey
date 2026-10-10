import 'dart:convert';

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
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/nutrition/presentation/foods_tab.dart';
import 'package:lifey/l10n/app_localizations.dart';

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
    throw UnimplementedError('never called - sync is a no-op in this test');
  }
}

/// The star on a food row (LIF-147): shows the mark, flips it with one tap (saved locally and queued with every stored field),
/// and the favourites are listed first.
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

  Future<void> pumpTab(WidgetTester tester, {double width = 360}) async {
    final foods = container.read(foodControllerProvider.notifier);
    await foods.addFood(name: 'Apple', calories: 52, protein: 0.3, servings: const [FoodServing(name: '1 apple', grams: 180)]);
    await foods.addFood(name: 'Skyr', calories: 60, protein: 11, favorite: true);
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FoodsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a favourite is listed first and its star says "Remove from favourites"', (tester) async {
    await pumpTab(tester);

    final names = tester.widgetList<Text>(find.byWidgetPredicate((w) => w is Text && (w.data == 'Skyr' || w.data == 'Apple'))).map((t) => t.data);
    expect(names, ['Skyr', 'Apple']);
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);
    expect(find.byTooltip('Add to favourites'), findsOneWidget);
  });

  testWidgets('tapping the star on a plain food makes it a favourite and moves it up; the update carries every stored field', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.byTooltip('Add to favourites'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add to favourites'), findsNothing);
    expect(find.byTooltip('Remove from favourites'), findsNWidgets(2));
    final rows = {for (final r in await db.select(db.foods).get()) r.name: r.favorite};
    expect(rows, {'Apple': true, 'Skyr': true});

    final updates = (await db.select(db.pendingOperations).get()).where((o) => o.operation == 'update').toList();
    final payload = jsonDecode(updates.single.payloadJson) as Map<String, dynamic>;
    expect(payload['favorite'], isTrue);
    expect(payload['name'], 'Apple');
    expect(payload['caloriesPer100g'], 52);
    expect(payload['servings'], [
      {'name': '1 apple', 'grams': 180.0},
    ]);
  });

  testWidgets('tapping the star on a favourite takes the mark off', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.byTooltip('Remove from favourites'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remove from favourites'), findsNothing);
    expect((await db.select(db.foods).get()).every((f) => !f.favorite), isTrue);
  });

  testWidgets('a narrow row with a long name does not overflow (360 dp, text scaled 1.3)', (tester) async {
    await container.read(foodControllerProvider.notifier).addFood(
          name: 'Nagyon hosszú nevű, többszörösen összetett élelmiszer',
          calories: 123,
          protein: 12,
          carbs: 34,
          fat: 5,
          favorite: true,
        );
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)), child: child!),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: FoodsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);
  });
}

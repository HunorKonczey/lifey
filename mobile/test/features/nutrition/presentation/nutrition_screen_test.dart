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
import 'package:lifey/features/nutrition/presentation/nutrition_screen.dart';
import 'package:lifey/features/nutrition/presentation/widgets/copy_day_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/lifey_header.dart';

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    throw UnimplementedError('never called — sync is a no-op in this test');
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _FailingAdapter();
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

  Future<void> pumpScreen(WidgetTester tester,
      {Size size = const Size(411, 923)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NutritionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('large title, copy-day and scanner buttons, four tabs',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(LifeyHeader), findsOneWidget);
    expect(find.text('Nutrition'), findsOneWidget);
    expect(find.byTooltip('Copy a previous day'), findsOneWidget);
    expect(find.byTooltip('Scan barcode'), findsOneWidget);
    // Meals is the first tab: nothing to search there.
    expect(find.byTooltip('Search'), findsNothing);
    for (final tab in ['Meals', 'Recipes', 'Foods', 'Macros']) {
      expect(find.text(tab), findsOneWidget, reason: tab);
    }
  });

  testWidgets('copy-day sheet opens from the header', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Copy a previous day'));
    await tester.pumpAndSettle();

    expect(find.byType(CopyDaySheet), findsOneWidget);
  });

  testWidgets('search appears on Recipes and Foods, opens and closes',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Recipes'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Search'), findsOneWidget);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(LifeySearchHeader), findsOneWidget);
    expect(find.text('Search recipes…'), findsOneWidget);
    expect(find.byType(LifeyHeader), findsNothing);
    // The tab bar stays while searching.
    expect(find.text('Foods'), findsOneWidget);

    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(find.byType(LifeyHeader), findsOneWidget);

    await tester.tap(find.text('Foods'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Search foods…'), findsOneWidget);
  });

  testWidgets('switching tabs closes an open search', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Foods'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'oat');

    await tester.tap(find.text('Macros'));
    await tester.pumpAndSettle();

    expect(find.byType(LifeySearchHeader), findsNothing);
    expect(find.byType(LifeyHeader), findsOneWidget);
  });
}

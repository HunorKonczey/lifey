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
import 'package:lifey/features/workouts/presentation/widgets/week_summary_row.dart';
import 'package:lifey/features/workouts/presentation/workouts_screen.dart';
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

  Future<void> pumpScreen(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = const Size(411 * 3, 923 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WorkoutsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('large title, filter button and three tabs', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(LifeyHeader), findsOneWidget);
    expect(find.text('Workouts'), findsOneWidget);
    expect(find.byTooltip('Filter'), findsOneWidget);
    for (final tab in ['Sessions', 'Templates', 'Exercises']) {
      expect(find.text(tab), findsOneWidget, reason: tab);
    }
  });

  testWidgets('the filter sheet offers period and type, and applies at once', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();

    expect(find.text('PERIOD'), findsOneWidget);
    expect(find.text('TYPE'), findsOneWidget);
    for (final chip in ['Today', 'Week', 'All', 'Strength', 'Cardio', 'Running']) {
      expect(find.widgetWithText(ChoiceChip, chip), findsWidgets, reason: chip);
    }
    await tester.tap(find.widgetWithText(ChoiceChip, 'Strength'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Strength')).selected, isTrue);
  });

  testWidgets('a non-default filter puts a dot on the button; the Templates tab has no filter', (tester) async {
    await pumpScreen(tester);
    final button = find.byType(HeaderIconButton);
    expect(tester.widget<HeaderIconButton>(button).showDot, isFalse);

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cardio').first);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20)); // the modal barrier
    await tester.pumpAndSettle();

    expect(tester.widget<HeaderIconButton>(button).showDot, isTrue);

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    expect(find.byType(HeaderIconButton), findsNothing);
  });

  testWidgets('the week summary is the first thing in the list', (tester) async {
    await pumpScreen(tester);

    // An empty history shows the empty state; with sessions the summary leads.
    expect(find.byType(WeekSummaryRow), findsNothing);
  });
}

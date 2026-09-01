import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/statistics/application/stats_range_controller.dart';
import 'package:lifey/features/statistics/presentation/statistics_screen.dart';
import 'package:lifey/features/steps/data/step_count_repository.dart';
import 'package:lifey/features/water/data/water_entry_repository.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/charts/stats_range.dart';

/// Covers the range popup's two locked rows (frame P11, `69` §4.1) at both
/// `historyDays: 30` and `historyDays: null` — the DV-9 fix (exactly one
/// check mark) and the locked-row tap opening the paywall instead of
/// changing the selection.

class _FakeMealController extends MealController {
  _FakeMealController(this._meals);
  final List<Meal> _meals;
  @override
  Stream<List<Meal>> build() => Stream.value(_meals);
}

class _EmptyWorkoutSessionController extends WorkoutSessionController {
  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);
}

class _EmptyWeightController extends WeightController {
  @override
  Stream<List<WeightEntry>> build() => Stream.value(const []);
}

class _FakeSettingsController extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

Meal _meal(DateTime dateTime) => Meal(
      clientId: 'meal-${dateTime.microsecondsSinceEpoch}',
      dateTime: dateTime,
      mealType: MealType.breakfast,
      entries: [
        const MealEntry(
          foodClientId: 'food',
          foodName: 'Food',
          quantityInGrams: 100,
          calories: 100,
          protein: 0,
          carbs: 0,
          fat: 0,
        ),
      ],
    );

Future<ProviderContainer> _pumpStatisticsScreen(
  WidgetTester tester, {
  required DateTime? historyCutoff,
}) async {
  late ProviderContainer container;
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          container = ProviderScope.containerOf(context);
          return const StatisticsScreen();
        },
      ),
      // Stands in for app_router.dart's real `/paywall` route — this file
      // only cares that a locked row navigates somewhere, not what.
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const Scaffold(body: Text('paywall')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mealControllerProvider.overrideWith(() => _FakeMealController([_meal(DateTime.now())])),
        workoutSessionControllerProvider.overrideWith(_EmptyWorkoutSessionController.new),
        weightControllerProvider.overrideWith(_EmptyWeightController.new),
        allWaterEntriesProvider.overrideWith((ref) => Stream.value(const [])),
        allStepCountsProvider.overrideWith((ref) => Stream.value(const [])),
        settingsControllerProvider.overrideWith(_FakeSettingsController.new),
        historyCutoffProvider.overrideWithValue(historyCutoff),
        // BannerAdSlot (67 Prompt 9) is embedded on this screen — without
        // this override it falls through to the real entitlementProvider
        // chain (Drift + dio), which never resolves in this test and leaves
        // a pending platform-channel call when the tree is disposed.
        adsEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

DateTime _thirtyDaysAgo() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(const Duration(days: 30));
}

Future<void> _openRangeMenu(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<StatsRange>));
  await tester.pumpAndSettle();
}

void main() {
  final cutoff30Days = _thirtyDaysAgo();

  testWidgets('historyDays: 30 locks "90 days" and "All" with a lock glyph', (tester) async {
    await _pumpStatisticsScreen(tester, historyCutoff: cutoff30Days);
    await _openRangeMenu(tester);

    expect(find.byIcon(Icons.lock), findsNWidgets(2));
    // Exactly one check mark — the DV-9 fix (`69` §11.2): the frame drew two.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('historyDays: null (Pro, or unresolved and fail-open) locks nothing', (tester) async {
    await _pumpStatisticsScreen(tester, historyCutoff: null);
    await _openRangeMenu(tester);

    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tapping a locked row opens the paywall instead of selecting it', (tester) async {
    final container = await _pumpStatisticsScreen(tester, historyCutoff: cutoff30Days);
    await _openRangeMenu(tester);

    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();

    // Unchanged from StatsRangeController's default.
    expect(container.read(statsRangeControllerProvider), StatsRange.month);
    expect(find.text('paywall'), findsOneWidget);
  });

  testWidgets('tapping an unlocked row selects it normally, without opening the paywall',
      (tester) async {
    final container = await _pumpStatisticsScreen(tester, historyCutoff: cutoff30Days);
    await _openRangeMenu(tester);

    await tester.tap(find.text('7 days').last);
    await tester.pumpAndSettle();

    expect(container.read(statsRangeControllerProvider), StatsRange.week);
    expect(find.text('paywall'), findsNothing);
  });
}

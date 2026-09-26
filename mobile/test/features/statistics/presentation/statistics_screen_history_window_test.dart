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
import 'package:lifey/shared/widgets/ds/lifey_segmented.dart';

/// Covers the range switcher's two locked segments (frame P11, `69` §4.1) at
/// both `historyDays: 30` and `historyDays: null` — the lock glyph, the reason
/// a screen reader hears, and a locked tap opening the paywall instead of
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

void main() {
  final cutoff30Days = _thirtyDaysAgo();

  testWidgets('historyDays: 30 locks "90 d" and "All" with a lock glyph', (tester) async {
    await _pumpStatisticsScreen(tester, historyCutoff: cutoff30Days);

    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
    expect(
      find.descendant(of: find.byType(LifeySegmented<StatsRange>), matching: find.byIcon(Icons.lock_rounded)),
      findsNWidgets(2),
    );
  });

  testWidgets('historyDays: null (Pro, or unresolved and fail-open) locks nothing', (tester) async {
    await _pumpStatisticsScreen(tester, historyCutoff: null);

    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  testWidgets('tapping a locked range opens the paywall instead of selecting it', (tester) async {
    final container = await _pumpStatisticsScreen(tester, historyCutoff: cutoff30Days);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // Unchanged from StatsRangeController's default.
    expect(container.read(statsRangeControllerProvider), StatsRange.month);
    expect(find.text('paywall'), findsOneWidget);
  });

  testWidgets('tapping an unlocked range selects it normally, without opening the paywall',
      (tester) async {
    final container = await _pumpStatisticsScreen(tester, historyCutoff: cutoff30Days);

    await tester.tap(find.text('7 d'));
    await tester.pumpAndSettle();

    expect(container.read(statsRangeControllerProvider), StatsRange.week);
    expect(find.text('paywall'), findsNothing);
  });

  testWidgets('a locked range explains *why* it is locked to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpStatisticsScreen(tester, historyCutoff: cutoff30Days);

    // `69` §8: "states the reason, not just 'locked'".
    expect(find.bySemanticsLabel('All — Pro required'), findsOneWidget);
    expect(find.bySemanticsLabel('90 d — Pro required'), findsOneWidget);
    handle.dispose();
  });
}

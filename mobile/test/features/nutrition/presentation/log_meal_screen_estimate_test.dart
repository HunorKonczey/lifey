import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/ads/interstitial_manager.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/application/remaining_budget_provider.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/nutrition/domain/remaining_budget.dart';
import 'package:lifey/features/nutrition/presentation/log_meal_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// The "Estimate from a photo" entry point (docs/23-ai-calorie-estimation-plan.md
/// "Mobile"): shown with its credit chip, and it never reaches the camera
/// when the estimate can't run — offline, or out of credits.

class _NoMeals extends MealController {
  @override
  Stream<List<Meal>> build() => Stream.value(const []);
}

class _NoAds extends InterstitialManager {
  _NoAds(super.ref);

  @override
  Future<void> maybeShow(BuildContext context, InterstitialReason reason) async {}
}

Future<void> _pump(WidgetTester tester, {required bool offline, required int? credits}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LogMealScreen()),
      GoRoute(path: '/paywall', builder: (_, __) => const Scaffold(body: Text('paywall'))),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mealControllerProvider.overrideWith(_NoMeals.new),
      interstitialManagerProvider.overrideWith(_NoAds.new),
      remainingBudgetProvider.overrideWithValue(const AsyncValue<RemainingBudget>.loading()),
      isOfflineProvider.overrideWith((ref) => Stream.value(offline)),
      aiCreditsProvider.overrideWithValue(credits),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the entry point with the remaining credits', (tester) async {
    await _pump(tester, offline: false, credits: 2);

    expect(find.text('Estimate from a photo'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('offline, it explains instead of opening the camera', (tester) async {
    await _pump(tester, offline: true, credits: 3);

    await tester.tap(find.text('Estimate from a photo'));
    await tester.pump();

    expect(find.textContaining('photo estimates need a connection'), findsOneWidget);
    expect(find.text('Take photo'), findsNothing);
  });

  testWidgets('out of credits, it opens the paywall instead', (tester) async {
    await _pump(tester, offline: false, credits: 0);

    await tester.tap(find.text('Estimate from a photo'));
    await tester.pumpAndSettle();

    expect(find.text('paywall'), findsOneWidget);
  });

  testWidgets('with credits, it asks for the photo source', (tester) async {
    await _pump(tester, offline: false, credits: 3);

    await tester.tap(find.text('Estimate from a photo'));
    await tester.pumpAndSettle();

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
  });
}

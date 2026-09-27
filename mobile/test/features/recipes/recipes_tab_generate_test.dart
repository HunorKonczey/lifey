import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/features/recipes/application/recipes_controller.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';
import 'package:lifey/features/recipes/generation/presentation/recipe_wizard_sheet.dart';
import 'package:lifey/features/recipes/presentation/recipes_tab.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// The AI entry point on the recipes list (docs/23-ai-calorie-estimation-plan.md
/// Phase 2): shown with its credit chip, and it never opens the wizard when the
/// generation couldn't run anyway — offline, or out of credits.

class _NoRecipes extends RecipeController {
  @override
  Stream<List<Recipe>> build() => Stream.value(const []);
}

Future<void> _pump(WidgetTester tester, {required bool offline, required int? credits}) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: RecipesTab())),
    GoRoute(path: '/paywall', builder: (_, __) => const Scaffold(body: Text('paywall'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      recipeControllerProvider.overrideWith(_NoRecipes.new),
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

    expect(find.text('Generate a recipe'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('offline, it explains instead of opening the wizard', (tester) async {
    await _pump(tester, offline: true, credits: 3);

    await tester.tap(find.text('Generate a recipe'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('generating a recipe needs a connection'), findsOneWidget);
    expect(find.byType(RecipeWizardSheet), findsNothing);
  });

  testWidgets('out of credits, it opens the paywall instead', (tester) async {
    await _pump(tester, offline: false, credits: 0);

    await tester.tap(find.text('Generate a recipe'));
    await tester.pumpAndSettle();

    expect(find.text('paywall'), findsOneWidget);
    expect(find.byType(RecipeWizardSheet), findsNothing);
  });

  testWidgets('with credits, it opens the wizard', (tester) async {
    await _pump(tester, offline: false, credits: 3);

    await tester.tap(find.text('Generate a recipe'));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeWizardSheet), findsOneWidget);
  });
}

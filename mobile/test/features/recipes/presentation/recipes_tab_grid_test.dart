import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/recipes/application/recipes_controller.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';
import 'package:lifey/features/recipes/presentation/recipes_tab.dart';
import 'package:lifey/features/recipes/presentation/widgets/recipe_grid_card.dart';
import 'package:lifey/l10n/app_localizations.dart';

Recipe _recipe(String name, double kcal, double protein, {bool favorite = false, int servings = 1}) => Recipe(
      clientId: name,
      name: name,
      favorite: favorite,
      servings: servings,
      ingredients: [
        RecipeIngredient(
          foodClientId: 'f-$name',
          foodName: name,
          quantityInGrams: 100,
          calories: kcal,
          protein: protein,
          carbs: 0,
          fat: 0,
        ),
      ],
    );

final _recipes = [
  _recipe('Chicken rice bowl', 520, 46, favorite: true),
  _recipe('Overnight oats', 383, 23),
  _recipe('Tuna pasta salad', 610, 38),
  _recipe('Greek yogurt parfait', 290, 21, favorite: true),
];

class _FakeRecipes extends RecipeController {
  final toggled = <(String, bool)>[];

  @override
  Stream<List<Recipe>> build() => Stream.value(_recipes);

  @override
  Future<void> toggleFavorite(String clientId, bool favorite) async => toggled.add((clientId, favorite));
}

Future<_FakeRecipes> _pump(
  WidgetTester tester, {
  String? query,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final fake = _FakeRecipes();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recipeControllerProvider.overrideWith(() => fake),
        isOfflineProvider.overrideWith((ref) => Stream.value(false)),
        aiCreditsProvider.overrideWithValue(null),
        syncStatusByClientIdProvider.overrideWithValue(const {}),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: RecipesTab(searchQuery: query)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Iterable<String> _names(WidgetTester tester) =>
    tester.widgetList<RecipeGridCard>(find.byType(RecipeGridCard)).map((c) => c.recipe.name);

void main() {
  testWidgets('entry card, four filter chips and every recipe as a card', (tester) async {
    await _pump(tester);

    expect(find.text('Generate a recipe'), findsOneWidget);
    expect(find.text("From what's in your fridge, sized to your goals"), findsOneWidget);
    for (final chip in ['All', 'Favourites', 'High protein', '< 400 kcal']) {
      expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget, reason: chip);
    }
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All')).selected, isTrue);
    expect(_names(tester), containsAll(['Chicken rice bowl', 'Overnight oats', 'Tuna pasta salad']));
    expect(find.text('520 kcal'), findsOneWidget);
    expect(find.text('46 g P'), findsOneWidget);
  });

  testWidgets('Favourites shows only the starred ones', (tester) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Favourites'));
    await tester.pumpAndSettle();

    expect(_names(tester).toSet(), {'Chicken rice bowl', 'Greek yogurt parfait'});
  });

  testWidgets('High protein: protein at least 30 % of the calories', (tester) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'High protein'));
    await tester.pumpAndSettle();

    // 46 g in 520 kcal = 35 %; 23 g in 383 = 24 %; 38 g in 610 = 25 %; 21 g in 290 = 29 %.
    expect(_names(tester).toSet(), {'Chicken rice bowl'});
  });

  testWidgets('< 400 kcal per serving', (tester) async {
    await _pump(tester);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '< 400 kcal'));
    await tester.tap(find.widgetWithText(ChoiceChip, '< 400 kcal'));
    await tester.pumpAndSettle();

    expect(_names(tester).toSet(), {'Overnight oats', 'Greek yogurt parfait'});
  });

  testWidgets('a filter combines with the header search', (tester) async {
    await _pump(tester, query: 'oats');
    expect(_names(tester).toSet(), {'Overnight oats'});

    await tester.tap(find.widgetWithText(ChoiceChip, 'Favourites'));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeGridCard), findsNothing);
    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('a filter with no match says so instead of showing a blank', (tester) async {
    await _pump(tester, query: 'pasta');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Favourites'));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeGridCard), findsNothing);
    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('searching hides the entry card', (tester) async {
    await _pump(tester, query: 'pasta');

    expect(find.text('Generate a recipe'), findsNothing);
    expect(_names(tester).toSet(), {'Tuna pasta salad'});
  });

  testWidgets('the star toggles the favourite', (tester) async {
    final fake = await _pump(tester);

    await tester.tap(find.byTooltip('Add to favourites').first);

    expect(fake.toggled, [('Overnight oats', true)]);
  });

  testWidgets('long-press opens Edit / Duplicate / Delete', (tester) async {
    await _pump(tester);

    await tester.longPress(find.text('Overnight oats'));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  for (final width in [411.0, 360.0]) {
    testWidgets('no overflow at ${width.toInt()} dp, text x1.3, HU', (tester) async {
      await _pump(tester, width: width, textScale: 1.3, locale: const Locale('hu'));

      expect(tester.takeException(), isNull);
      expect(find.text('Recept generálása'), findsOneWidget);
    });
  }
}

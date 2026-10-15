import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/nutrition/application/recipe_usage_provider.dart';
import 'package:lifey/features/nutrition/domain/recipe_usage.dart';
import 'package:lifey/features/nutrition/presentation/widgets/add_recipe_sheet.dart';
import 'package:lifey/features/recipes/application/recipes_controller.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';
import 'package:lifey/l10n/app_localizations.dart';

RecipeIngredient _ingredient(String name, double grams, {double kcal = 0, double protein = 0}) => RecipeIngredient(
      foodClientId: 'food-$name',
      foodName: name,
      quantityInGrams: grams,
      calories: kcal,
      protein: protein,
      carbs: 0,
      fat: 0,
    );

/// Four servings: 400 g beans (400 kcal) + 400 g beef (1000 kcal).
final _chilli = Recipe(
  clientId: 'chilli',
  name: 'Chilli',
  servings: 4,
  ingredients: [_ingredient('Beans', 400, kcal: 400, protein: 24), _ingredient('Beef', 400, kcal: 1000, protein: 80)],
);

final _recipes = [
  Recipe(clientId: 'z', name: 'Zucchini bake', ingredients: [_ingredient('Zucchini', 300, kcal: 60)]),
  _chilli,
  Recipe(clientId: 'k', name: 'Töltött káposzta', favorite: true, ingredients: [_ingredient('Cabbage', 300, kcal: 200)]),
  const Recipe(clientId: 'e', name: 'Empty one', ingredients: []),
  Recipe(clientId: 'a', name: 'Apple pie', ingredients: [_ingredient('Apples', 200, kcal: 100)]),
];

class _FakeRecipes extends RecipeController {
  _FakeRecipes(this.recipes);

  final List<Recipe> recipes;

  @override
  Stream<List<Recipe>> build() => Stream.value(recipes);
}

/// Opens the sheet from a button, the way the Log meal screen does, and keeps what it popped with.
class _Harness {
  AddRecipeResult? result;
  bool popped = false;
}

Future<_Harness> _open(WidgetTester tester, {List<Recipe>? recipes, Map<String, RecipeUsage> usage = const {}}) async {
  tester.view.physicalSize = const Size(411 * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final harness = _Harness();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recipeControllerProvider.overrideWith(() => _FakeRecipes(recipes ?? _recipes)),
        recipeUsageProvider.overrideWith((ref) => Stream.value(usage)),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  harness.result = await showModalBottomSheet<AddRecipeResult>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const AddRecipeSheet(),
                  );
                  harness.popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

/// The sheet's text fields in order: the search field (picker) or the servings field then one per ingredient.
Finder get _fields => find.byType(TextField);

void main() {
  group('picker', () {
    testWidgets('lists favourites first, then A to Z', (tester) async {
      await _open(tester);

      final order = ['Töltött káposzta', 'Apple pie', 'Chilli', 'Empty one', 'Zucchini bake'];
      final ys = [for (final name in order) tester.getTopLeft(find.text(name)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    testWidgets('the recipes eaten most recently lead, before the favourites', (tester) async {
      await _open(tester, usage: {
        'z': RecipeUsage(lastUsedAt: DateTime(2026, 10, 9), useCount: 3),
        'a': RecipeUsage(lastUsedAt: DateTime(2026, 10, 2), useCount: 1),
      });

      final order = ['Zucchini bake', 'Apple pie', 'Töltött káposzta', 'Chilli'];
      final ys = [for (final name in order) tester.getTopLeft(find.text(name)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    testWidgets('search ignores case and accents', (tester) async {
      await _open(tester);

      await tester.enterText(_fields, 'TOLTOTT');
      await tester.pumpAndSettle();

      expect(find.text('Töltött káposzta'), findsOneWidget);
      expect(find.text('Chilli'), findsNothing);
    });

    testWidgets('a search without a match says so', (tester) async {
      await _open(tester);

      await tester.enterText(_fields, 'sushi');
      await tester.pumpAndSettle();

      expect(find.text('No recipe matches'), findsOneWidget);
    });

    testWidgets('without recipes it explains', (tester) async {
      await _open(tester, recipes: const []);

      expect(find.text('No recipes yet'), findsOneWidget);
    });

    testWidgets('a recipe without ingredients cannot be picked', (tester) async {
      await _open(tester);

      await tester.tap(find.text('Empty one'));
      await tester.pumpAndSettle();

      expect(find.text('Servings eaten'), findsNothing);
      expect(find.text('Search recipes…'), findsOneWidget);
    });
  });

  group('portion', () {
    Future<_Harness> openChilli(WidgetTester tester) async {
      final harness = await _open(tester);
      await tester.tap(find.text('Chilli'));
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('one serving of a four-serving recipe is a quarter of every ingredient', (tester) async {
      final harness = await openChilli(tester);

      await tester.tap(find.text('Add to meal'));
      await tester.pumpAndSettle();

      expect(harness.result!.recipe.clientId, 'chilli');
      expect(harness.result!.drafts.map((d) => d.food.name), ['Beans', 'Beef']);
      expect(harness.result!.drafts.map((d) => d.grams), [100, 100]);
    });

    testWidgets('the preview shows the macros of what will be added', (tester) async {
      await openChilli(tester);

      // (400 + 1000) / 4 kcal, (24 + 80) / 4 g protein.
      expect(find.textContaining('350'), findsWidgets);
      expect(find.textContaining('26'), findsWidgets);
    });

    testWidgets('plus adds half a serving and the grams follow', (tester) async {
      final harness = await openChilli(tester);

      await tester.tap(find.byTooltip('More servings'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '1.5'), findsOneWidget);

      await tester.tap(find.text('Add to meal'));
      await tester.pumpAndSettle();

      expect(harness.result!.drafts.map((d) => d.grams), [150, 150]);
    });

    testWidgets('typed servings are used, an out-of-range value is ignored', (tester) async {
      final harness = await openChilli(tester);

      await tester.enterText(_fields.first, '2');
      await tester.pumpAndSettle();
      await tester.enterText(_fields.first, '500');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to meal'));
      await tester.pumpAndSettle();

      expect(harness.result!.drafts.map((d) => d.grams), [200, 200]);
    });

    testWidgets('a draft food carries per-100 g figures that reproduce the recipe', (tester) async {
      final harness = await openChilli(tester);

      await tester.tap(find.text('Add to meal'));
      await tester.pumpAndSettle();

      final beef = harness.result!.drafts.last;
      expect(beef.food.clientId, 'food-Beef');
      expect(beef.food.caloriesPer100g, closeTo(250, 1e-9));
      expect(beef.food.caloriesPer100g * beef.grams / 100, closeTo(250, 1e-9));
    });

    testWidgets('an ingredient set to 0 g is left out', (tester) async {
      final harness = await openChilli(tester);

      await tester.tap(find.text('Adjust ingredients'));
      await tester.pumpAndSettle();
      await tester.enterText(_fields.at(2), '0');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to meal'));
      await tester.pumpAndSettle();

      expect(harness.result!.drafts.map((d) => d.food.name), ['Beans']);
    });

    testWidgets('a typed amount survives a change of servings', (tester) async {
      final harness = await openChilli(tester);

      await tester.tap(find.text('Adjust ingredients'));
      await tester.pumpAndSettle();
      await tester.enterText(_fields.at(1), '60');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More servings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to meal'));
      await tester.pumpAndSettle();

      expect(harness.result!.drafts.map((d) => d.grams), [60, 150]);
    });

    testWidgets('with every amount at 0 there is nothing to add', (tester) async {
      await openChilli(tester);

      await tester.tap(find.text('Adjust ingredients'));
      await tester.pumpAndSettle();
      await tester.enterText(_fields.at(1), '0');
      await tester.enterText(_fields.at(2), '0');
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add to meal'));
      expect(button.onPressed, isNull);
    });

    testWidgets('back returns to the picker without adding anything', (tester) async {
      final harness = await openChilli(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Search recipes…'), findsOneWidget);
      expect(harness.popped, isFalse);
    });

    testWidgets('picking another recipe starts from one serving again', (tester) async {
      await openChilli(tester);
      await tester.tap(find.byTooltip('More servings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apple pie'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '1'), findsOneWidget);
    });
  });
}

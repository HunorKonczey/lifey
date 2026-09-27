import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/nutrition/presentation/widgets/meal_summary_panel.dart';
import 'package:lifey/features/recipes/application/recipes_controller.dart';
import 'package:lifey/features/recipes/data/recipe_repository.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';
import 'package:lifey/features/recipes/presentation/create_recipe_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakeRecipes extends RecipeController {
  final updates = <({String id, int servings, bool favorite})>[];

  @override
  Stream<List<Recipe>> build() => Stream.value([_recipe]);

  @override
  Future<void> updateRecipe(
    String clientId, {
    required String name,
    String? description,
    bool favorite = false,
    int servings = 1,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    updates.add((id: clientId, servings: servings, favorite: favorite));
  }
}

RecipeIngredient _ing(String name, double grams, double kcal, double protein) => RecipeIngredient(
      foodClientId: name,
      foodName: name,
      quantityInGrams: grams,
      calories: kcal,
      protein: protein,
      carbs: kcal / 8,
      fat: kcal / 30,
    );

final _recipe = Recipe(
  clientId: 'oats',
  name: 'Overnight oats',
  servings: 2,
  ingredients: [_ing('Rolled oats', 60, 227, 8), _ing('Greek yogurt', 150, 110, 15)],
);

Future<_FakeRecipes> _pump(
  WidgetTester tester, {
  Recipe? recipe,
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
      overrides: [recipeControllerProvider.overrideWith(() => fake)],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CreateRecipeScreen(recipe: recipe)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('edit layout: header with Save, fields, servings, favourite, ingredient rows, actions, summary', (tester) async {
    await _pump(tester, recipe: _recipe);

    expect(find.text('Edit recipe'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Overnight oats'), findsOneWidget);
    expect(find.text('INGREDIENTS · 2'), findsOneWidget);
    expect(find.text('60 g · 8 g protein'), findsOneWidget);
    expect(find.text('Add food', skipOffstage: false), findsOneWidget);
    expect(find.text('Macros only', skipOffstage: false), findsOneWidget);
    expect(find.text('Recipe total'), findsOneWidget);
    expect(tester.widget<MealSummaryPanel>(find.byType(MealSummaryPanel)).calories, 337);
    expect(find.byIcon(Icons.more_vert_rounded), findsNWidgets(2));
  });

  testWidgets('the servings stepper autosaves the change', (tester) async {
    final fake = await _pump(tester, recipe: _recipe);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(fake.updates.last.servings, 3);
  });

  testWidgets('removing an ingredient from its ⋮ menu updates the list and the total', (tester) async {
    final fake = await _pump(tester, recipe: _recipe);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('INGREDIENTS · 1'), findsOneWidget);
    expect(tester.widget<MealSummaryPanel>(find.byType(MealSummaryPanel)).calories, 110);
    expect(fake.updates, isNotEmpty);
  });

  testWidgets('a new recipe has no ingredient rows and no summary yet', (tester) async {
    await _pump(tester);

    expect(find.text('New recipe'), findsOneWidget);
    expect(find.textContaining('INGREDIENTS'), findsNothing);
    expect(find.byType(MealSummaryPanel), findsNothing);
  });

  testWidgets('Save closes the screen', (tester) async {
    await _pump(tester, recipe: _recipe);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateRecipeScreen), findsNothing);
  });

  for (final width in [411.0, 360.0]) {
    testWidgets('no overflow at ${width.toInt()} dp, text x1.3, HU', (tester) async {
      await _pump(tester, recipe: _recipe, width: width, textScale: 1.3, locale: const Locale('hu'));

      expect(tester.takeException(), isNull);
    });
  }
}

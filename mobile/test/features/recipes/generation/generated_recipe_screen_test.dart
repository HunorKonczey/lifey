import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/features/nutrition/application/food_controller.dart';
import 'package:lifey/features/nutrition/data/food_repository.dart';
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/recipes/application/recipes_controller.dart';
import 'package:lifey/features/recipes/data/recipe_repository.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';
import 'package:lifey/features/recipes/generation/application/recipe_generation_controller.dart';
import 'package:lifey/features/recipes/generation/domain/generated_recipe.dart';
import 'package:lifey/features/recipes/generation/domain/recipe_wizard.dart';
import 'package:lifey/features/recipes/generation/presentation/generated_recipe_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakeGeneration extends RecipeGenerationController {
  _FakeGeneration(this._result);

  final RecipeGenerationState _result;
  int calls = 0;

  @override
  RecipeGenerationState build() => const RecipeGenerationIdle();

  @override
  Future<void> generate(RecipeWizardAnswers answers) async {
    calls++;
    state = const RecipeGenerationLoading();
    await Future<void>.delayed(Duration.zero);
    state = _result;
  }
}

class _FakeFoods extends FoodController {
  final created = <String>[];

  @override
  Stream<List<Food>> build() => Stream.value(const []);

  @override
  Future<Food> addFood({
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
    String? barcode,
    bool hidden = false,
  }) async {
    created.add(name);
    return Food(
        clientId: 'new-${created.length}', name: name,
        caloriesPer100g: calories, proteinPer100g: protein);
  }
}

class _FakeFoodRepository implements FoodRepository {
  @override
  Future<Food?> findByServerId(int serverId) async => const Food(
      clientId: 'chicken-local', id: 7, name: 'Chicken breast',
      caloriesPer100g: 165, proteinPer100g: 31);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRecipes extends RecipeController {
  List<RecipeIngredientInput>? ingredients;
  String? name;
  int? servings;

  @override
  Stream<List<Recipe>> build() => Stream.value(const []);

  @override
  Future<String> createRecipe({
    required String name,
    String? description,
    bool favorite = false,
    int servings = 1,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    this.name = name;
    this.servings = servings;
    this.ingredients = ingredients;
    return 'recipe-1';
  }
}

const _proposal = GeneratedRecipe(
  name: 'Chicken and rice',
  description: '1. Cook it.',
  servings: 2,
  ingredients: [
    GeneratedIngredient(name: 'Chicken breast', quantityInGrams: 300, existingFoodId: 7),
    GeneratedIngredient(
        name: 'Jasmine rice',
        quantityInGrams: 150,
        newFood: GeneratedNewFood(
            name: 'Jasmine rice', caloriesPer100g: 355, proteinPer100g: 7,
            carbsPer100g: 78, fatPer100g: 0.6)),
  ],
  perServing: RecipeMacros(calories: 530, protein: 52, carbs: 59, fat: 6),
);

void main() {
  late _FakeGeneration generation;
  late _FakeFoods foods;
  late _FakeRecipes recipes;

  Future<void> open(WidgetTester tester, RecipeGenerationState result) async {
    generation = _FakeGeneration(result);
    foods = _FakeFoods();
    recipes = _FakeRecipes();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The screen is always pushed on top of the recipes list in the app, and
    // it pops itself after saving — so the test needs a route under it too.
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/generate'),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(
          path: '/generate',
          builder: (_, __) => const GeneratedRecipeScreen(
              answers: RecipeWizardAnswers(
                  dietType: RecipeDietType.meat,
                  mealType: RecipeMealType.dinner,
                  calorieBand: RecipeCalorieBand.from500To700))),
      GoRoute(path: '/paywall', builder: (_, __) => const Scaffold(body: Text('paywall'))),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        recipeGenerationControllerProvider.overrideWith(() => generation),
        foodControllerProvider.overrideWith(() => foods),
        recipeControllerProvider.overrideWith(() => recipes),
        foodRepositoryProvider.overrideWithValue(_FakeFoodRepository()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows which ingredients are already in the catalog', (tester) async {
    await open(tester, const RecipeGenerationDone(_proposal));

    expect(find.text('Already in your foods'), findsOneWidget);
    expect(find.text('Will be added to your foods'), findsOneWidget);
    expect(find.textContaining('530 kcal'), findsOneWidget);
  });

  testWidgets('saves the proposal as an ordinary recipe', (tester) async {
    await open(tester, const RecipeGenerationDone(_proposal));

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(recipes.name, 'Chicken and rice');
    expect(recipes.ingredients!.map((i) => i.foodClientId), ['chicken-local', 'new-1']);
    expect(foods.created, ['Jasmine rice']);
  });

  testWidgets('a removed ingredient is left out of the saved recipe', (tester) async {
    await open(tester, const RecipeGenerationDone(_proposal));

    await tester.tap(find.byTooltip('Leave this out').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(recipes.ingredients!.single.foodClientId, 'new-1');
  });

  testWidgets('try again re-runs the same answers', (tester) async {
    await open(tester, const RecipeGenerationDone(_proposal));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(generation.calls, 2);
  });

  testWidgets('a failure is retryable and says no credit was used', (tester) async {
    await open(tester, const RecipeGenerationFailed());

    expect(find.textContaining('No credit was used'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(generation.calls, 2);
  });

  testWidgets('out of credits leaves for the paywall', (tester) async {
    await open(tester, const RecipeGenerationCreditsExhausted());

    expect(find.text('paywall'), findsOneWidget);
  });
}

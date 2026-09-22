import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/application/food_controller.dart';
import 'package:lifey/features/nutrition/data/food_repository.dart';
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/recipes/application/recipes_controller.dart';
import 'package:lifey/features/recipes/data/recipe_repository.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';
import 'package:lifey/features/recipes/generation/application/generated_recipe_saver.dart';
import 'package:lifey/features/recipes/generation/domain/generated_recipe.dart';

/// Saving a proposal (docs/23-ai-calorie-estimation-plan.md Phase 2): new foods
/// are created, existing ones are resolved from the server id the backend
/// referenced, and the recipe is written through the ordinary local-first path.

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
      clientId: 'new-${created.length}',
      name: name,
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      hidden: hidden,
    );
  }
}

class _FakeFoodRepository implements FoodRepository {
  _FakeFoodRepository(this._byServerId);

  final Map<int, Food> _byServerId;

  @override
  Future<Food?> findByServerId(int serverId) async => _byServerId[serverId];

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

const _existing = GeneratedIngredient(
    name: 'Chicken breast', quantityInGrams: 300, existingFoodId: 7);
const _newRice = GeneratedIngredient(
    name: 'Jasmine rice',
    quantityInGrams: 150,
    newFood: GeneratedNewFood(
        name: 'Jasmine rice',
        caloriesPer100g: 355,
        proteinPer100g: 7,
        carbsPer100g: 78,
        fatPer100g: 0.6));

GeneratedRecipe _recipe(List<GeneratedIngredient> ingredients) => GeneratedRecipe(
      name: 'Chicken and rice',
      description: '1. Cook it.',
      servings: 2,
      ingredients: ingredients,
      perServing: const RecipeMacros(calories: 530, protein: 52, carbs: 59, fat: 6),
    );

void main() {
  late _FakeFoods foods;
  late _FakeRecipes recipes;

  ProviderContainer containerWith(Map<int, Food> catalog) {
    foods = _FakeFoods();
    recipes = _FakeRecipes();
    final container = ProviderContainer(overrides: [
      foodControllerProvider.overrideWith(() => foods),
      recipeControllerProvider.overrideWith(() => recipes),
      foodRepositoryProvider.overrideWithValue(_FakeFoodRepository(catalog)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  const chicken = Food(
      clientId: 'chicken-local', id: 7, name: 'Chicken breast',
      caloriesPer100g: 165, proteinPer100g: 31);

  test('creates the new foods and reuses the existing one by server id', () async {
    final container = containerWith({7: chicken});

    final saved = await container.read(generatedRecipeSaverProvider).save(
          _recipe(const [_existing, _newRice]),
          name: 'Chicken and rice',
          servings: 2,
        );

    expect(saved.clientId, 'recipe-1');
    expect(saved.skippedIngredients, 0);
    expect(foods.created, ['Jasmine rice']);
    expect(recipes.ingredients!.map((i) => i.foodClientId), ['chicken-local', 'new-1']);
    expect(recipes.ingredients!.map((i) => i.grams), [300, 150]);
    expect(recipes.servings, 2);
  });

  test('edited quantities win, and a null drops the ingredient', () async {
    final container = containerWith({7: chicken});

    await container.read(generatedRecipeSaverProvider).save(
          _recipe(const [_existing, _newRice]),
          name: 'Chicken and rice',
          servings: 3,
          quantities: {0: 250, 1: null},
        );

    expect(recipes.ingredients!.single.grams, 250);
    expect(foods.created, isEmpty);
  });

  test('an existing food that never synced down is skipped, not invented', () async {
    final container = containerWith(const {});

    final saved = await container.read(generatedRecipeSaverProvider).save(
          _recipe(const [_existing, _newRice]),
          name: 'Rice',
          servings: 1,
        );

    expect(saved.skippedIngredients, 1);
    expect(recipes.ingredients!.single.foodClientId, 'new-1');
  });

  test('a proposal with nothing left to save fails instead of writing an empty recipe', () async {
    final container = containerWith(const {});

    await expectLater(
      container.read(generatedRecipeSaverProvider).save(
            _recipe(const [_existing]),
            name: 'Nothing',
            servings: 1,
          ),
      throwsStateError,
    );
    expect(recipes.ingredients, isNull);
  });
}

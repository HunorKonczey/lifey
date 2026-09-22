import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_repository.dart';
import 'package:lifey/features/recipes/generation/application/recipe_generation_controller.dart';
import 'package:lifey/features/recipes/generation/data/recipe_generation_repository.dart';
import 'package:lifey/features/recipes/generation/domain/generated_recipe.dart';
import 'package:lifey/features/recipes/generation/domain/recipe_wizard.dart';

const _answers = RecipeWizardAnswers(
  dietType: RecipeDietType.vegan,
  mealType: RecipeMealType.lunch,
  calorieBand: RecipeCalorieBand.from300To500,
);

class _FakeRepo implements RecipeGenerationRepository {
  _FakeRepo(this._answer);

  final Future<GeneratedRecipe> Function() _answer;

  @override
  Future<GeneratedRecipe> generate(RecipeWizardAnswers answers) => _answer();
}

class _FakeEntitlements implements EntitlementRepository {
  int refreshes = 0;

  @override
  Future<bool> refresh() async {
    refreshes++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DioException _status(int code) {
  final options = RequestOptions(path: '/recipes/generate');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: code),
  );
}

void main() {
  late _FakeEntitlements entitlements;

  ProviderContainer containerWith(Future<GeneratedRecipe> Function() answer) {
    entitlements = _FakeEntitlements();
    final container = ProviderContainer(overrides: [
      recipeGenerationRepositoryProvider.overrideWithValue(_FakeRepo(answer)),
      entitlementRepositoryProvider.overrideWithValue(entitlements),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  const recipe = GeneratedRecipe(
    name: 'Lentil soup',
    description: '1. Simmer.',
    servings: 4,
    ingredients: [
      GeneratedIngredient(
          name: 'Red lentils',
          quantityInGrams: 300,
          newFood: GeneratedNewFood(
              name: 'Red lentils', caloriesPer100g: 352, proteinPer100g: 24,
              carbsPer100g: 60, fatPer100g: 1)),
    ],
    perServing: RecipeMacros(calories: 320, protein: 18, carbs: 45, fat: 4),
  );

  test('a successful generation is exposed and refreshes the credit count', () async {
    final container = containerWith(() async => recipe);

    await container.read(recipeGenerationControllerProvider.notifier).generate(_answers);

    final state = container.read(recipeGenerationControllerProvider);
    expect(state, isA<RecipeGenerationDone>());
    expect((state as RecipeGenerationDone).recipe, same(recipe));
    expect(entitlements.refreshes, 1);
  });

  test('402 means the monthly AI credits are used up', () async {
    final container = containerWith(() => Future.error(_status(402)));

    await container.read(recipeGenerationControllerProvider.notifier).generate(_answers);

    expect(container.read(recipeGenerationControllerProvider),
        isA<RecipeGenerationCreditsExhausted>());
    expect(entitlements.refreshes, 0);
  });

  test('502 from the model is a retryable failure', () async {
    final container = containerWith(() => Future.error(_status(502)));

    await container.read(recipeGenerationControllerProvider.notifier).generate(_answers);

    expect(container.read(recipeGenerationControllerProvider), isA<RecipeGenerationFailed>());
  });

  test('no connection is reported as offline', () async {
    final container = containerWith(() => Future.error(DioException(
          requestOptions: RequestOptions(path: '/recipes/generate'),
          type: DioExceptionType.connectionError,
        )));

    await container.read(recipeGenerationControllerProvider.notifier).generate(_answers);

    expect(container.read(recipeGenerationControllerProvider), isA<RecipeGenerationOffline>());
  });

  test('parses the backend payload, keeping both ingredient shapes', () {
    final parsed = GeneratedRecipe.fromJson({
      'name': 'Chicken and rice',
      'description': '1. Cook it.',
      'servings': 2,
      'ingredients': [
        {'existingFoodId': 7, 'newFood': null, 'name': 'Chicken breast', 'quantityInGrams': 300},
        {
          'existingFoodId': null,
          'newFood': {
            'name': 'Jasmine rice',
            'caloriesPer100g': 355,
            'proteinPer100g': 7,
            'carbsPer100g': 78,
            'fatPer100g': 0.6,
          },
          'name': 'Jasmine rice',
          'quantityInGrams': 150,
        },
      ],
      'perServing': {'calories': 530, 'proteinGrams': 52, 'carbsGrams': 59, 'fatGrams': 6},
    });

    expect(parsed.ingredients.first.isNew, isFalse);
    expect(parsed.ingredients.first.existingFoodId, 7);
    expect(parsed.ingredients.last.isNew, isTrue);
    expect(parsed.ingredients.last.newFood!.caloriesPer100g, 355);
    expect(parsed.perServing.calories, 530);
  });
}

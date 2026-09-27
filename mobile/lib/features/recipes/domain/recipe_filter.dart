import 'recipe.dart';

/// Share of a recipe's calories that must come from protein for "High protein"
/// (docs/redesign/77-mobile-redesign-plan.md R2, data note): protein grams × 4
/// kcal ≥ 30 % of the recipe's kcal.
const highProteinCalorieShare = 0.30;

/// "< 400 kcal": the calories **per serving** must be under this.
const lowCalorieServingLimit = 400;

/// The filter chips of the Recipes tab.
enum RecipeFilter { all, favourites, highProtein, lowCalorie }

/// Calories of one serving (the whole recipe when it has a single serving).
double caloriesPerServing(Recipe recipe) =>
    recipe.totalCalories / (recipe.servings > 0 ? recipe.servings : 1);

/// Protein grams of one serving.
double proteinPerServing(Recipe recipe) =>
    recipe.totalProtein / (recipe.servings > 0 ? recipe.servings : 1);

/// Whether [recipe] passes [filter]. A recipe without calories is never
/// "high protein" (there is no share to take) and is "< 400 kcal" only when
/// it really has none — an empty recipe is not a light meal.
bool matchesRecipeFilter(Recipe recipe, RecipeFilter filter) => switch (filter) {
      RecipeFilter.all => true,
      RecipeFilter.favourites => recipe.favorite,
      RecipeFilter.highProtein =>
        recipe.totalCalories > 0 && recipe.totalProtein * 4 / recipe.totalCalories >= highProteinCalorieShare,
      RecipeFilter.lowCalorie => recipe.totalCalories > 0 && caloriesPerServing(recipe) < lowCalorieServingLimit,
    };

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meal_repository.dart';
import '../domain/recipe_usage.dart';

/// Per-recipe usage stats (last used, count) from the meals' recipe tags, for the Add-recipe picker's ordering.
final recipeUsageProvider = StreamProvider.autoDispose<Map<String, RecipeUsage>>((ref) {
  return ref.watch(mealRepositoryProvider).watchRecipeUsage();
});

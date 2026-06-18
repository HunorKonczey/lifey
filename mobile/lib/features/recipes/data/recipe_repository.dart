import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for recipe data (remote API + local cache).
abstract interface class RecipeRepository {
  // CRUD operations for recipes go here.
}

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  throw UnimplementedError();
});

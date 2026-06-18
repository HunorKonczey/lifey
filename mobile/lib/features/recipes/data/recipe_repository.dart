import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/recipe.dart';

/// One ingredient to include when creating a recipe (request side).
class RecipeIngredientInput {
  const RecipeIngredientInput({required this.foodId, required this.grams});

  final int foodId;
  final double grams;
}

/// REST access to the `/recipes` endpoints.
class RecipeRepository {
  RecipeRepository(this._dio);

  final Dio _dio;

  Future<List<Recipe>> fetchAll() async {
    final response = await _dio.get<List<dynamic>>('/recipes');
    return (response.data ?? const [])
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Recipe> create({
    required String name,
    String? description,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>('/recipes', data: {
      'name': name,
      'description': description,
      'ingredients': ingredients
          .map((i) => {'foodId': i.foodId, 'quantityInGrams': i.grams})
          .toList(),
    });
    return Recipe.fromJson(response.data!);
  }

  Future<Recipe> update(
    int id, {
    required String name,
    String? description,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>('/recipes/$id', data: {
      'name': name,
      'description': description,
      'ingredients': ingredients
          .map((i) => {'foodId': i.foodId, 'quantityInGrams': i.grams})
          .toList(),
    });
    return Recipe.fromJson(response.data!);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/recipes/$id');
  }
}

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(dioClientProvider));
});

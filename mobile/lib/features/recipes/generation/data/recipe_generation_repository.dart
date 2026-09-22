import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/generated_recipe.dart';
import '../domain/recipe_wizard.dart';

/// Online-only recipe generation (`POST /recipes/generate`,
/// docs/23-ai-calorie-estimation-plan.md Phase 2). Never touches the local
/// drift cache or the outbox — the proposal becomes local data only when the
/// user saves it, through the ordinary recipe flow.
class RecipeGenerationRepository {
  RecipeGenerationRepository(this._dio);

  final Dio _dio;

  /// Writing a recipe takes the model longer than reading a photo, and the
  /// client-wide 10 s receive timeout would cut off answers on their way.
  static const receiveTimeout = Duration(seconds: 90);

  Future<GeneratedRecipe> generate(RecipeWizardAnswers answers) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.recipeGenerate,
      data: answers.toJson(),
      options: Options(receiveTimeout: receiveTimeout),
    );
    return GeneratedRecipe.fromJson(response.data!);
  }
}

final recipeGenerationRepositoryProvider = Provider<RecipeGenerationRepository>((ref) {
  return RecipeGenerationRepository(ref.watch(dioClientProvider));
});

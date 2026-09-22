import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/entitlements/entitlement_repository.dart';
import '../data/recipe_generation_repository.dart';
import '../domain/generated_recipe.dart';
import '../domain/recipe_wizard.dart';

/// Outcome of a recipe generation, surfaced to the UI.
sealed class RecipeGenerationState {
  const RecipeGenerationState();
}

class RecipeGenerationIdle extends RecipeGenerationState {
  const RecipeGenerationIdle();
}

class RecipeGenerationLoading extends RecipeGenerationState {
  const RecipeGenerationLoading();
}

class RecipeGenerationDone extends RecipeGenerationState {
  const RecipeGenerationDone(this.recipe);
  final GeneratedRecipe recipe;
}

/// 402 `AI_CREDITS_EXHAUSTED` — the server is authoritative over the credit
/// count (`67` §3.4); the UI routes this to the paywall.
class RecipeGenerationCreditsExhausted extends RecipeGenerationState {
  const RecipeGenerationCreditsExhausted();
}

/// Couldn't reach the backend at all (no connectivity, timeout).
class RecipeGenerationOffline extends RecipeGenerationState {
  const RecipeGenerationOffline();
}

/// The server answered with an error — 502 `AI_UNAVAILABLE`, 503, or a 400
/// from an answer combination the wizard shouldn't have allowed. No credit was
/// used; the user can retry.
class RecipeGenerationFailed extends RecipeGenerationState {
  const RecipeGenerationFailed();
}

/// Drives a single `POST /recipes/generate` call. Online-only: no drift read,
/// no outbox entry.
class RecipeGenerationController extends Notifier<RecipeGenerationState> {
  RecipeGenerationRepository get _repo => ref.read(recipeGenerationRepositoryProvider);

  @override
  RecipeGenerationState build() => const RecipeGenerationIdle();

  Future<void> generate(RecipeWizardAnswers answers) async {
    state = const RecipeGenerationLoading();
    try {
      final recipe = await _repo.generate(answers);
      state = RecipeGenerationDone(recipe);
      // A successful call used a credit server-side; refresh so the chip shows
      // the new count instead of waiting for the next stale check.
      // refresh() never throws.
      unawaited(ref.read(entitlementRepositoryProvider).refresh());
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        state = const RecipeGenerationCreditsExhausted();
      } else if (_isConnectivityFailure(e)) {
        state = const RecipeGenerationOffline();
      } else {
        state = const RecipeGenerationFailed();
      }
    }
  }

  void reset() => state = const RecipeGenerationIdle();

  bool _isConnectivityFailure(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
  }
}

final recipeGenerationControllerProvider =
    NotifierProvider<RecipeGenerationController, RecipeGenerationState>(
        RecipeGenerationController.new);

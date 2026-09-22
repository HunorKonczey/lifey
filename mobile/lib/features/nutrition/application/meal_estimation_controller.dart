import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/entitlements/entitlement_repository.dart';
import '../data/meal_estimation_repository.dart';
import '../domain/meal_estimate.dart';

/// Outcome of an AI meal-photo estimate, surfaced to the UI.
sealed class MealEstimationState {
  const MealEstimationState();
}

class MealEstimationIdle extends MealEstimationState {
  const MealEstimationIdle();
}

class MealEstimationLoading extends MealEstimationState {
  const MealEstimationLoading();
}

class MealEstimationDone extends MealEstimationState {
  const MealEstimationDone(this.estimate);
  final MealEstimate estimate;
}

/// 402 `AI_CREDITS_EXHAUSTED` — the server is authoritative over the local
/// credit count (`67` §3.4); the UI routes this to the paywall.
class MealEstimationCreditsExhausted extends MealEstimationState {
  const MealEstimationCreditsExhausted();
}

/// Couldn't reach the backend at all (no connectivity, timeout).
class MealEstimationOffline extends MealEstimationState {
  const MealEstimationOffline();
}

/// The server answered with an error — 502 `AI_UNAVAILABLE`, 503, an
/// unreadable image. No credit was used; the user can retry.
class MealEstimationFailed extends MealEstimationState {
  const MealEstimationFailed();
}

/// Drives a single `POST /meals/estimate` call. Online-only: no drift read,
/// no outbox entry.
class MealEstimationController extends Notifier<MealEstimationState> {
  MealEstimationRepository get _repo => ref.read(mealEstimationRepositoryProvider);

  @override
  MealEstimationState build() => const MealEstimationIdle();

  Future<void> estimate(String imagePath) async {
    state = const MealEstimationLoading();
    try {
      final result = await _repo.estimate(imagePath);
      state = MealEstimationDone(result);
      // A successful call used a credit server-side; refresh so the chip
      // shows the new count instead of waiting for the next stale check.
      // refresh() never throws.
      unawaited(ref.read(entitlementRepositoryProvider).refresh());
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        state = const MealEstimationCreditsExhausted();
      } else if (_isConnectivityFailure(e)) {
        state = const MealEstimationOffline();
      } else {
        state = const MealEstimationFailed();
      }
    }
  }

  void reset() => state = const MealEstimationIdle();

  bool _isConnectivityFailure(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
  }
}

final mealEstimationControllerProvider =
    NotifierProvider<MealEstimationController, MealEstimationState>(
        MealEstimationController.new);

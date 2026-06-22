import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/food_repository.dart';
import '../domain/food.dart';

/// Streams foods from the local cache and exposes the mutations themselves.
class FoodController extends StreamNotifier<List<Food>> {
  FoodRepository get _repo => ref.read(foodRepositoryProvider);

  @override
  Stream<List<Food>> build() => _repo.watchAll();

  Future<void> addFood({
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
    String? barcode,
  }) {
    return _repo.create(
        name: name, calories: calories, protein: protein, carbs: carbs, fat: fat, barcode: barcode);
  }

  Future<void> updateFood(
    String clientId, {
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
    String? barcode,
  }) {
    return _repo.update(clientId,
        name: name, calories: calories, protein: protein, carbs: carbs, fat: fat, barcode: barcode);
  }

  Future<void> deleteFood(String clientId) {
    return _repo.delete(clientId);
  }

  /// Drains the outbox, then re-pulls from the server — matching what the
  /// dashboard's pull-to-refresh does. Without the pull half, swiping to
  /// refresh only pushes local edits and never reconciles a stale/corrupted
  /// local row with the server's truth.
  Future<void> refresh() async {
    try {
      await ref.read(syncEngineProvider).sync();
      await ref.read(pullEngineProvider).pullAll();
    } catch (_) {
      // Best-effort: no connectivity or a backend hiccup leaves the cache as-is.
    }
  }
}

final foodControllerProvider =
    StreamNotifierProvider<FoodController, List<Food>>(FoodController.new);

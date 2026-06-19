import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }) {
    return _repo.create(name: name, calories: calories, protein: protein, carbs: carbs, fat: fat);
  }

  Future<void> updateFood(
    String clientId, {
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
  }) {
    return _repo.update(clientId,
        name: name, calories: calories, protein: protein, carbs: carbs, fat: fat);
  }

  Future<void> deleteFood(String clientId) {
    return _repo.delete(clientId);
  }

  Future<void> refresh() => ref.read(syncEngineProvider).sync();
}

final foodControllerProvider =
    StreamNotifierProvider<FoodController, List<Food>>(FoodController.new);

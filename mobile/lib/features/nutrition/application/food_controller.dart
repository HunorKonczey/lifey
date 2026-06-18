import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/food_repository.dart';
import '../domain/food.dart';

/// Loads and mutates the list of foods. Mutations rethrow on failure and reload
/// the authoritative list from the server on success.
class FoodController extends AsyncNotifier<List<Food>> {
  FoodRepository get _repo => ref.read(foodRepositoryProvider);

  @override
  Future<List<Food>> build() => _repo.fetchAll();

  Future<void> addFood({
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
  }) async {
    await _repo.create(
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> updateFood(
    int id, {
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
  }) async {
    await _repo.update(
      id,
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> deleteFood(int id) async {
    await _repo.delete(id);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchAll);
  }
}

final foodControllerProvider =
    AsyncNotifierProvider<FoodController, List<Food>>(FoodController.new);

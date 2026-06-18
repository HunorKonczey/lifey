import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meal_repository.dart';
import '../domain/meal.dart';

/// Loads and mutates the list of logged meals.
class MealController extends AsyncNotifier<List<Meal>> {
  MealRepository get _repo => ref.read(mealRepositoryProvider);

  @override
  Future<List<Meal>> build() => _repo.fetchAll();

  Future<void> logMeal({
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
  }) async {
    await _repo.create(dateTime: dateTime, mealType: mealType, entries: entries);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> updateMeal(
    int id, {
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
  }) async {
    await _repo.update(id, dateTime: dateTime, mealType: mealType, entries: entries);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> deleteMeal(int id) async {
    await _repo.delete(id);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchAll);
  }
}

final mealControllerProvider =
    AsyncNotifierProvider<MealController, List<Meal>>(MealController.new);

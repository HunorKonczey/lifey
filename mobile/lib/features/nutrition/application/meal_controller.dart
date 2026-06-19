import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_engine_provider.dart';
import '../data/meal_repository.dart';
import '../domain/meal.dart';

/// Streams logged meals from the local cache and exposes the mutations.
class MealController extends StreamNotifier<List<Meal>> {
  MealRepository get _repo => ref.read(mealRepositoryProvider);

  @override
  Stream<List<Meal>> build() => _repo.watchAll();

  Future<void> logMeal({
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
  }) {
    return _repo.create(dateTime: dateTime, mealType: mealType, entries: entries);
  }

  Future<void> updateMeal(
    String clientId, {
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
  }) {
    return _repo.update(clientId, dateTime: dateTime, mealType: mealType, entries: entries);
  }

  Future<void> deleteMeal(String clientId) => _repo.delete(clientId);

  Future<void> refresh() => ref.read(syncEngineProvider).sync();
}

final mealControllerProvider =
    StreamNotifierProvider<MealController, List<Meal>>(MealController.new);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_repository.dart';
import '../domain/exercise.dart';

/// The exercise master list: read by the template/session pickers and managed
/// (add/delete) from the Workouts > Exercises tab.
class ExerciseController extends AsyncNotifier<List<Exercise>> {
  ExerciseRepository get _repo => ref.read(exerciseRepositoryProvider);

  @override
  Future<List<Exercise>> build() => _repo.fetchAll();

  Future<void> addExercise(String name) async {
    await _repo.create(name);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> deleteExercise(int id) async {
    await _repo.delete(id);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchAll);
  }
}

final exerciseControllerProvider =
    AsyncNotifierProvider<ExerciseController, List<Exercise>>(
        ExerciseController.new);

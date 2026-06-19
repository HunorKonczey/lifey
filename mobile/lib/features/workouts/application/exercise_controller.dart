import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_engine_provider.dart';
import '../data/exercise_repository.dart';
import '../domain/exercise.dart';

/// The exercise master list: read by the template/session pickers and managed
/// (add/delete) from the Workouts > Exercises tab.
class ExerciseController extends StreamNotifier<List<Exercise>> {
  ExerciseRepository get _repo => ref.read(exerciseRepositoryProvider);

  @override
  Stream<List<Exercise>> build() => _repo.watchAll();

  Future<void> addExercise(String name) => _repo.create(name);

  Future<void> deleteExercise(String clientId) => _repo.delete(clientId);

  Future<void> refresh() => ref.read(syncEngineProvider).sync();
}

final exerciseControllerProvider =
    StreamNotifierProvider<ExerciseController, List<Exercise>>(ExerciseController.new);

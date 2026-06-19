import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workout_session_repository.dart';
import '../domain/workout_session.dart';

/// Loads and creates workout sessions (the API has no update/delete).
class WorkoutSessionController extends AsyncNotifier<List<WorkoutSession>> {
  WorkoutSessionRepository get _repo => ref.read(workoutSessionRepositoryProvider);

  @override
  Future<List<WorkoutSession>> build() => _repo.fetchAll();

  Future<void> logSession({
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<int> exerciseIds,
    required List<ExerciseSetInput> sets,
  }) async {
    await _repo.create(
        startedAt: startedAt, finishedAt: finishedAt, exerciseIds: exerciseIds, sets: sets);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> updateSession(
    int id, {
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<int> exerciseIds,
    required List<ExerciseSetInput> sets,
  }) async {
    await _repo.update(id,
        startedAt: startedAt, finishedAt: finishedAt, exerciseIds: exerciseIds, sets: sets);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> deleteSession(int id) async {
    await _repo.delete(id);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchAll);
  }
}

final workoutSessionControllerProvider =
    AsyncNotifierProvider<WorkoutSessionController, List<WorkoutSession>>(
        WorkoutSessionController.new);

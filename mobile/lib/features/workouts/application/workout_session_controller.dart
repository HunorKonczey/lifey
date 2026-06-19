import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_engine_provider.dart';
import '../data/workout_session_repository.dart';
import '../domain/workout_session.dart';

/// Streams workout sessions from the local cache and exposes the mutations.
class WorkoutSessionController extends StreamNotifier<List<WorkoutSession>> {
  WorkoutSessionRepository get _repo => ref.read(workoutSessionRepositoryProvider);

  @override
  Stream<List<WorkoutSession>> build() => _repo.watchAll();

  Future<void> logSession({
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<String> exerciseClientIds,
    required List<ExerciseSetInput> sets,
  }) {
    return _repo.create(
      startedAt: startedAt,
      finishedAt: finishedAt,
      exerciseClientIds: exerciseClientIds,
      sets: sets,
    );
  }

  Future<void> updateSession(
    String clientId, {
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<String> exerciseClientIds,
    required List<ExerciseSetInput> sets,
  }) {
    return _repo.update(
      clientId,
      startedAt: startedAt,
      finishedAt: finishedAt,
      exerciseClientIds: exerciseClientIds,
      sets: sets,
    );
  }

  Future<void> deleteSession(String clientId) => _repo.delete(clientId);

  Future<void> refresh() => ref.read(syncEngineProvider).sync();
}

final workoutSessionControllerProvider =
    StreamNotifierProvider<WorkoutSessionController, List<WorkoutSession>>(
        WorkoutSessionController.new);

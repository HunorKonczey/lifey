import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/exercise_repository.dart';
import '../domain/exercise.dart';

/// The exercise master list: read by the template/session pickers and managed
/// (add/delete) from the Workouts > Exercises tab.
class ExerciseController extends StreamNotifier<List<Exercise>> {
  ExerciseRepository get _repo => ref.read(exerciseRepositoryProvider);

  @override
  Stream<List<Exercise>> build() => _repo.watchAll();

  Future<void> addExercise(String name, {String? category, String? equipment}) =>
      _repo.create(name, category: category, equipment: equipment);

  Future<void> updateExercise(
    String clientId, {
    required String name,
    String? category,
    String? equipment,
  }) =>
      _repo.update(clientId, name: name, category: category, equipment: equipment);

  Future<void> deleteExercise(String clientId) => _repo.delete(clientId);

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

final exerciseControllerProvider =
    StreamNotifierProvider<ExerciseController, List<Exercise>>(ExerciseController.new);

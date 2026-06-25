import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/workout_template_repository.dart';
import '../domain/workout_template.dart';

/// Streams workout templates from the local cache and exposes the mutations.
class WorkoutTemplateController extends StreamNotifier<List<WorkoutTemplate>> {
  WorkoutTemplateRepository get _repo => ref.read(workoutTemplateRepositoryProvider);

  @override
  Stream<List<WorkoutTemplate>> build() => _repo.watchAll();

  Future<void> createTemplate({
    required String name,
    required List<TemplateExercise> exercises,
  }) {
    return _repo.create(name: name, exercises: exercises);
  }

  Future<void> updateTemplate({
    required String clientId,
    required String name,
    required List<TemplateExercise> exercises,
  }) {
    return _repo.update(clientId, name: name, exercises: exercises);
  }

  Future<void> deleteTemplate(String clientId) => _repo.delete(clientId);

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

final workoutTemplateControllerProvider =
    StreamNotifierProvider<WorkoutTemplateController, List<WorkoutTemplate>>(
        WorkoutTemplateController.new);

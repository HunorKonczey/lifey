import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../../../core/sync/sync_status_provider.dart';
import '../data/workout_session_repository.dart';
import '../domain/workout_session.dart';

/// Streams workout sessions from the local cache and exposes the mutations.
class WorkoutSessionController extends StreamNotifier<List<WorkoutSession>> {
  WorkoutSessionRepository get _repo => ref.read(workoutSessionRepositoryProvider);

  @override
  Stream<List<WorkoutSession>> build() {
    // A session with a delete in flight stays in storage (so a server
    // rejection can bring it back with its exercises/sets intact and a
    // failed marker), so it must be filtered out here rather than relying
    // on the row being gone.
    final activelyDeleting = ref.watch(activelyDeletingClientIdsProvider);
    return _repo
        .watchAll()
        .map((sessions) => sessions.where((s) => !activelyDeleting.contains(s.clientId)).toList());
  }

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

final workoutSessionControllerProvider =
    StreamNotifierProvider<WorkoutSessionController, List<WorkoutSession>>(
        WorkoutSessionController.new);

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/workout_session_repository.dart';
import '../domain/workout_session.dart';

/// Streams workout sessions from the local cache and exposes the mutations.
class WorkoutSessionController extends StreamNotifier<List<WorkoutSession>> {
  WorkoutSessionRepository get _repo => ref.read(workoutSessionRepositoryProvider);

  @override
  Stream<List<WorkoutSession>> build() => _repo.watchAll();

  /// Returns the new session's clientId so the caller can keep editing it.
  Future<String> logSession({
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<PlannedExerciseInput> exercises,
    required List<ExerciseSetInput> sets,
    String? templateClientId,
    String? templateName,
    int? rpe,
    String? feedbackNote,
  }) {
    return _repo.create(
      startedAt: startedAt,
      finishedAt: finishedAt,
      exercises: exercises,
      sets: sets,
      templateClientId: templateClientId,
      templateName: templateName,
      rpe: rpe,
      feedbackNote: feedbackNote,
    );
  }

  /// Manually logs a finished cardio session — `LogCardioSheet`
  /// (docs/cardio/59-cardio-implementation-plan.md C1.8). [startedAt] can be
  /// in the past; [finishedAt] is derived from it plus [movingSeconds] since
  /// a manual entry has no separate pause/gross time to account for.
  /// Returns the new session's clientId.
  Future<String> logCardioSession({
    required DateTime startedAt,
    required String activityType,
    required int movingSeconds,
    CardioMetrics? cardio,
    int? rpe,
    String? feedbackNote,
  }) {
    return _repo.create(
      startedAt: startedAt,
      finishedAt: startedAt.add(Duration(seconds: movingSeconds)),
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: activityType,
      movingSeconds: movingSeconds,
      cardio: cardio,
      rpe: rpe,
      feedbackNote: feedbackNote,
    );
  }

  /// Starts a **live** cardio session — `CardioSessionScreen`
  /// (docs/cardio/59-cardio-implementation-plan.md C2.1). Begins already
  /// `RUNNING`: `movingSinceEpochMs` is set to [startedAt]'s own epoch, so
  /// the very first tick already counts. Returns the new session's clientId.
  Future<String> startCardioSession({
    required DateTime startedAt,
    required String activityType,
  }) {
    return _repo.create(
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: activityType,
      movingSeconds: 0,
      movingSinceEpochMs: startedAt.millisecondsSinceEpoch,
    );
  }

  /// Pauses a running cardio session: folds the just-finished running
  /// interval into `movingSeconds` and clears the checkpoint.
  /// [movingSeconds] is the caller's already-computed total (typically
  /// `WorkoutSession.liveMovingSeconds(DateTime.now())` at the moment of
  /// pausing) — resolving "now" is the caller's job, not the repository's,
  /// so this stays trivially testable without a fake clock.
  Future<void> pauseCardioSession(
    String clientId, {
    required DateTime startedAt,
    required int movingSeconds,
  }) {
    return _repo.update(
      clientId,
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
      movingSeconds: Value(movingSeconds),
      movingSinceEpochMs: const Value(null),
    );
  }

  /// Resumes a paused cardio session: opens a new running interval at
  /// [resumedAt]. `movingSeconds` is left untouched (absent) — it already
  /// holds the total accumulated up to the pause.
  Future<void> resumeCardioSession(
    String clientId, {
    required DateTime startedAt,
    required DateTime resumedAt,
  }) {
    return _repo.update(
      clientId,
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
      movingSinceEpochMs: Value(resumedAt.millisecondsSinceEpoch),
    );
  }

  /// Finishes a cardio session: folds any still-running interval into the
  /// final `movingSeconds` total (same caller-computes-"now" convention as
  /// [pauseCardioSession]) and sets [finishedAt].
  Future<void> finishCardioSession(
    String clientId, {
    required DateTime startedAt,
    required DateTime finishedAt,
    required int movingSeconds,
  }) {
    return _repo.update(
      clientId,
      startedAt: startedAt,
      finishedAt: finishedAt,
      exercises: const [],
      sets: const [],
      movingSeconds: Value(movingSeconds),
      movingSinceEpochMs: const Value(null),
    );
  }

  Future<void> updateSession(
    String clientId, {
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<PlannedExerciseInput> exercises,
    required List<ExerciseSetInput> sets,
    int? rpe,
    String? feedbackNote,
  }) {
    // Health enrichment fields (activeCalories/averageHeartRate/
    // healthWorkoutId) are deliberately left absent: the session editor
    // doesn't hold them, and the repository preserves absent fields, so an
    // edit can't disconnect an already-paired Apple Health workout.
    return _repo.update(
      clientId,
      startedAt: startedAt,
      finishedAt: finishedAt,
      exercises: exercises,
      sets: sets,
      rpe: Value(rpe),
      feedbackNote: Value(feedbackNote),
    );
  }

  /// Rates a finished session's difficulty without needing its full editing
  /// state in memory — see [WorkoutSessionRepository.rate].
  Future<void> rateSession(
    String clientId, {
    required int rpe,
    String? feedbackNote,
  }) {
    return _repo.rate(clientId, rpe: rpe, feedbackNote: feedbackNote);
  }

  /// Applies a watch-workout summary (docs/40-watch-app-plan.md §6.3) to
  /// [clientId] without disturbing rpe/feedbackNote or the session's
  /// exercises/sets — see [WorkoutSessionRepository.enrichHealthMetrics].
  Future<void> enrichFromWatch(
    String clientId, {
    required double? activeCalories,
    required double? averageHeartRate,
    required String? healthWorkoutId,
  }) {
    return _repo.enrichHealthMetrics(
      clientId,
      activeCalories: Value(activeCalories),
      averageHeartRate: Value(averageHeartRate),
      healthWorkoutId: Value(healthWorkoutId),
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

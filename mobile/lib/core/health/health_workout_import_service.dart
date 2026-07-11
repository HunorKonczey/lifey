import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workouts/application/workout_session_controller.dart';
import '../../features/workouts/data/workout_session_repository.dart';
import '../../features/workouts/domain/workout_session.dart';
import 'health_service.dart';
import 'health_workout.dart';

/// Backs the manual "Import from Health" action on the active workout
/// (docs/16-apple-health-integration-plan.md Phase 1 REVISED,
/// docs/26-android-health-connect-integration-plan.md). It is fully
/// user-initiated — there is no background detection or notification.
///
/// Responsibilities are split so the widget owns the UI (button + confirmation
/// dialog) and this service owns the health-store read + dedup + the single
/// write that closes and enriches the session:
/// - [findImportable] is read-only: it never touches app data.
/// - [importInto] performs the one write, and only the widget calls it after
///   the user confirms.
class HealthWorkoutImportService {
  HealthWorkoutImportService(this._ref);

  final Ref _ref;

  /// Look back this far for a just-finished Apple strength workout — wide
  /// enough to cover "I finished in Apple Fitness a while ago and only now
  /// opened Lifey to import it", not just an immediate same-minute tap.
  static const _window = Duration(days: 1);

  /// Wider lookback for [findImportableCandidates] — the manual picker on an
  /// already-closed session covers "I closed Lifey before my Apple Watch
  /// workout ended, and only now got around to pairing it", which can be more
  /// than a day later.
  static const _candidatesWindow = Duration(days: 14);

  /// The most recently finished strength workout from the last day that isn't
  /// already imported into a session, or null if there's nothing to import.
  /// Read-only.
  Future<HealthWorkout?> findImportable() async {
    final workouts =
        await _ref.read(healthServiceProvider).recentStrengthWorkouts(within: _window);
    if (workouts.isEmpty) return null;

    final alreadyImported = _alreadyImportedIds();
    // recentStrengthWorkouts is sorted most-recently-finished first.
    for (final workout in workouts) {
      if (!alreadyImported.contains(workout.uuid)) return workout;
    }
    return null;
  }

  /// Up to [limit] most-recently-finished strength workouts (within
  /// [_candidatesWindow]) that aren't already imported into any session, most
  /// recent first. Backs the manual "pick a workout to pair" sheet a user can
  /// open on a session that's already been closed. Read-only.
  Future<List<HealthWorkout>> findImportableCandidates({int limit = 5}) async {
    final workouts = await _ref
        .read(healthServiceProvider)
        .recentStrengthWorkouts(within: _candidatesWindow);
    if (workouts.isEmpty) return const [];

    final alreadyImported = _alreadyImportedIds();
    return workouts
        .where((w) => !alreadyImported.contains(w.uuid))
        .take(limit)
        .toList();
  }

  Set<String> _alreadyImportedIds() {
    final sessions = _ref.read(workoutSessionControllerProvider).value ?? const <WorkoutSession>[];
    return sessions.map((s) => s.healthWorkoutId).whereType<String>().toSet();
  }

  /// Closes + enriches the session [sessionClientId] with [workout]'s data,
  /// keeping its existing planned exercises and logged sets. Called only after
  /// the user confirms the import.
  Future<void> importInto({
    required String sessionClientId,
    required DateTime startedAt,
    required List<PlannedExerciseInput> exercises,
    required List<ExerciseSetInput> sets,
    required HealthWorkout workout,
  }) {
    // rpe/feedbackNote are deliberately left absent: this flow doesn't own
    // the rating, and the repository preserves absent fields, so pairing a
    // Health workout can't wipe a rating saved earlier.
    return _ref.read(workoutSessionRepositoryProvider).update(
          sessionClientId,
          startedAt: startedAt,
          finishedAt: workout.endDate,
          exercises: exercises,
          sets: sets,
          activeCalories: Value(workout.activeCalories),
          averageHeartRate: Value(workout.averageHeartRate),
          healthWorkoutId: Value(workout.uuid),
        );
  }
}

final healthWorkoutImportServiceProvider = Provider<HealthWorkoutImportService>((ref) {
  return HealthWorkoutImportService(ref);
});

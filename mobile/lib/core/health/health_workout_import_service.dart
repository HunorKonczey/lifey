import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workouts/application/workout_session_controller.dart';
import '../../features/workouts/data/workout_session_repository.dart';
import '../../features/workouts/domain/workout_session.dart';
import 'apple_workout.dart';
import 'health_service.dart';

/// Backs the manual "Import from Apple Health" action on the active workout
/// (docs/16-apple-health-integration-plan.md, Phase 1 REVISED). It is fully
/// user-initiated — there is no background detection or notification anymore.
///
/// Responsibilities are split so the widget owns the UI (button + confirmation
/// dialog) and this service owns the HealthKit read + dedup + the single write
/// that closes and enriches the session:
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

  /// The most recently finished strength workout from the last day that isn't
  /// already imported into a session, or null if there's nothing to import.
  /// Read-only.
  Future<AppleWorkout?> findImportable() async {
    final workouts =
        await _ref.read(healthServiceProvider).recentStrengthWorkouts(within: _window);
    if (workouts.isEmpty) return null;

    final sessions = _ref.read(workoutSessionControllerProvider).value ?? const <WorkoutSession>[];
    final alreadyImported =
        sessions.map((s) => s.healthWorkoutId).whereType<String>().toSet();

    // recentStrengthWorkouts is sorted most-recently-finished first.
    for (final workout in workouts) {
      if (!alreadyImported.contains(workout.uuid)) return workout;
    }
    return null;
  }

  /// Closes + enriches the session [sessionClientId] with [workout]'s data,
  /// keeping its existing planned exercises and logged sets. Called only after
  /// the user confirms the import.
  Future<void> importInto({
    required String sessionClientId,
    required DateTime startedAt,
    required List<String> exerciseClientIds,
    required List<ExerciseSetInput> sets,
    required AppleWorkout workout,
  }) {
    return _ref.read(workoutSessionRepositoryProvider).update(
          sessionClientId,
          startedAt: startedAt,
          finishedAt: workout.endDate,
          exerciseClientIds: exerciseClientIds,
          sets: sets,
          activeCalories: workout.activeCalories,
          averageHeartRate: workout.averageHeartRate,
          healthWorkoutId: workout.uuid,
        );
  }
}

final healthWorkoutImportServiceProvider = Provider<HealthWorkoutImportService>((ref) {
  return HealthWorkoutImportService(ref);
});

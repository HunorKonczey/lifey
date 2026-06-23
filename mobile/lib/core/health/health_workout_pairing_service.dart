import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workouts/application/workout_session_controller.dart';
import '../../features/workouts/data/workout_session_repository.dart';
import '../../features/workouts/domain/workout_session.dart';
import '../../l10n/app_localizations.dart';
import '../router/app_router.dart';
import 'health_workout_observer.dart';

/// Runs ONLY when the user taps the "workout ended" notification — wired via
/// [HealthWorkoutObserverService.onWorkoutNotificationTapped]. Detection
/// itself never modifies data; this is the single place a paired session
/// actually gets closed + enriched with Apple Health data, and only after
/// the user explicitly confirms (docs/16-apple-health-integration-plan.md,
/// Phase 1).
class HealthWorkoutPairingService {
  HealthWorkoutPairingService(this._ref);

  final Ref _ref;

  static const _matchWindow = Duration(minutes: 15);

  Future<void> handle(HealthWorkoutEvent event) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final sessions =
        _ref.read(workoutSessionControllerProvider).value ?? const <WorkoutSession>[];

    // Already paired (e.g. the user re-tapped a notification still sitting in
    // Notification Center after pairing it once) — never pair the same
    // HKWorkout twice.
    if (sessions.any((s) => s.healthWorkoutId == event.uuid)) return;

    final candidate = _findCandidate(sessions, event);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (candidate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.noMatchingActiveWorkoutMessage)));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pairAppleWorkoutTitle),
        content: Text(l10n.pairAppleWorkoutMessage(
          TimeOfDay.fromDateTime(event.startDate.toLocal()).format(ctx),
          event.activeCalories?.round().toString() ?? '–',
          event.averageHeartRate?.round().toString() ?? '–',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.cancelButton)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.pairButton)),
        ],
      ),
    );
    if (confirmed != true) return;

    await _ref.read(workoutSessionRepositoryProvider).update(
          candidate.clientId,
          startedAt: candidate.startedAt,
          finishedAt: event.endDate,
          exerciseClientIds: candidate.exercises.map((e) => e.exerciseClientId).toList(),
          sets: candidate.sets
              .map((s) => ExerciseSetInput(
                    exerciseClientId: s.exerciseClientId,
                    reps: s.reps,
                    weight: s.weight,
                    performedAt: s.performedAt,
                  ))
              .toList(),
          activeCalories: event.activeCalories,
          averageHeartRate: event.averageHeartRate,
          healthWorkoutId: event.uuid,
        );
  }

  /// Closest-start in-progress session within ±15 minutes of the Apple
  /// workout's start, or null if none matches.
  WorkoutSession? _findCandidate(List<WorkoutSession> sessions, HealthWorkoutEvent event) {
    WorkoutSession? best;
    Duration? bestDelta;
    for (final session in sessions) {
      if (!session.inProgress) continue;
      final delta = session.startedAt.difference(event.startDate).abs();
      if (delta > _matchWindow) continue;
      if (bestDelta == null || delta < bestDelta) {
        best = session;
        bestDelta = delta;
      }
    }
    return best;
  }
}

final healthWorkoutPairingServiceProvider = Provider<HealthWorkoutPairingService>((ref) {
  return HealthWorkoutPairingService(ref);
});

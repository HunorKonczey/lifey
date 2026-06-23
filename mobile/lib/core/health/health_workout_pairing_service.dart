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

  static const _logTag = '[HealthWorkoutPairing]';

  Future<void> handle(HealthWorkoutEvent event) async {
    debugPrint('$_logTag handle(${event.uuid}) called');
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('$_logTag rootNavigatorKey.currentContext is null, aborting');
      return;
    }

    final sessionsState = _ref.read(workoutSessionControllerProvider);
    final sessions = sessionsState.value ?? const <WorkoutSession>[];
    debugPrint('$_logTag sessionsState=${sessionsState.runtimeType} '
        '(isLoading=${sessionsState.isLoading}, hasValue=${sessionsState.hasValue}), '
        'sessions count=${sessions.length}');

    // Already paired (e.g. the user re-tapped a notification still sitting in
    // Notification Center after pairing it once) — never pair the same
    // HKWorkout twice.
    if (sessions.any((s) => s.healthWorkoutId == event.uuid)) {
      debugPrint('$_logTag ${event.uuid} already paired to a session, aborting');
      return;
    }

    final candidate = _findCandidate(sessions, event);
    debugPrint('$_logTag candidate=${candidate?.clientId ?? "none"}');
    if (!context.mounted) {
      debugPrint('$_logTag context no longer mounted, aborting');
      return;
    }
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
    debugPrint('$_logTag dialog result: confirmed=$confirmed');
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
    debugPrint('$_logTag paired and updated session ${candidate.clientId}');
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

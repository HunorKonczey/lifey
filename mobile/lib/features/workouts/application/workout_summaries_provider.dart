import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workout_session_repository.dart';
import '../domain/workout_session.dart';

/// Every workout session *without its children* (LIF-155, docs/14-pagination-plan.md Phase 1.3): the session's own fields and its
/// cardio metrics, but no planned exercises, sets, splits or waypoints - those are **empty here, not "none logged"**.
///
/// What the derived views read - the streaks, the weekly recap, the statistics, the recommended and quick-start workouts, the
/// dashboard counts, the cardio record baseline. None of them looks at a set, so none of them should pay for reading the whole
/// history's sets, nor be rebuilt each time one is logged. Anything that does look at sets reads [workoutSessionsWithSetsProvider]
/// (the Sessions list's record counts, the watch sync), [workoutSessionProvider] (one session, whole) or a window
/// (`workoutSessionsPagedProvider`, `recentWorkoutSessionsProvider`).
final workoutSummariesProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(workoutSessionRepositoryProvider).watchSummaries();
});

/// Every session with its sets and cardio metrics, but no planned exercises, splits or waypoints (LIF-156): for the views that
/// replay the history's sets - the Sessions list's record counts, the watch's "last time" prefill. Those that only need to know a
/// session happened read [workoutSummariesProvider]; the ones that need a single session whole read [workoutSessionProvider].
final workoutSessionsWithSetsProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(workoutSessionRepositoryProvider).watchWithSets();
});

/// One session, whole - its planned exercises, sets, splits and waypoints - kept up to date; null once it is gone. What a screen
/// that follows a single session (the live log screen mirroring the watch) watches instead of the whole history.
final workoutSessionProvider = StreamProvider.family<WorkoutSession?, String>((ref, clientId) {
  return ref.watch(workoutSessionRepositoryProvider).watchOne(clientId);
});

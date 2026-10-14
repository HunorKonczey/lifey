import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workout_session_repository.dart';
import '../domain/workout_session.dart';

/// Every workout session *without its children* (LIF-155, docs/14-pagination-plan.md Phase 1.3): the session's own fields and its
/// cardio metrics, but no planned exercises, sets, splits or waypoints - those are **empty here, not "none logged"**.
///
/// What the derived views read - the streaks, the weekly recap, the statistics, the recommended and quick-start workouts, the
/// dashboard counts, the cardio record baseline. None of them looks at a set, so none of them should pay for reading the whole
/// history's sets, nor be rebuilt each time one is logged. Anything that does look at sets (the Sessions list's record counts, the
/// live log screen, the watch sync) keeps reading `workoutSessionControllerProvider`, or a window of it.
final workoutSummariesProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(workoutSessionRepositoryProvider).watchSummaries();
});

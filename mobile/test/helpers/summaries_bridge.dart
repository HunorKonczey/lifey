import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:lifey/features/workouts/application/session_pr_counts.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/application/workout_summaries_provider.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// Makes `workoutSummariesProvider` (LIF-155) serve whatever the test's fake `workoutSessionControllerProvider` serves, so a test
/// that fakes the sessions once feeds both the consumers of the whole list and those of the children-free summaries. Put it next to
/// the controller override.
final Override summariesFollowController = workoutSummariesProvider.overrideWith((ref) {
  final controller = StreamController<List<WorkoutSession>>();
  ref.listen(
    workoutSessionControllerProvider,
    (previous, next) => next.whenData(controller.add),
    fireImmediately: true,
  );
  ref.onDispose(controller.close);
  return controller.stream;
});

/// The same for `workoutSessionsWithSetsProvider` (LIF-156): the record counts and the watch prefill read the sets.
final Override sessionsWithSetsFollowController = workoutSessionsWithSetsProvider.overrideWith((ref) {
  final controller = StreamController<List<WorkoutSession>>();
  ref.listen(
    workoutSessionControllerProvider,
    (previous, next) => next.whenData(controller.add),
    fireImmediately: true,
  );
  ref.onDispose(controller.close);
  return controller.stream;
});

/// The same for `strengthPrCountsProvider` (LIF-158): the Sessions list's record counts. The database counts them in the app; here the
/// fake sessions are counted with the Dart reference (`computeSessionPrCounts`), which the SQL is tested against.
final Override strengthPrCountsFollowController = strengthPrCountsProvider.overrideWith((ref) {
  final controller = StreamController<Map<String, int>>();
  ref.listen(
    workoutSessionControllerProvider,
    (previous, next) => next.whenData(
      (sessions) => controller.add(computeSessionPrCounts([for (final s in sessions) if (!s.isCardio) s])),
    ),
    fireImmediately: true,
  );
  ref.onDispose(controller.close);
  return controller.stream;
});

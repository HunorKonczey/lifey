import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

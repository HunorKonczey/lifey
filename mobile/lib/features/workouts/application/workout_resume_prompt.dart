import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../auth/application/auth_controller.dart';
import '../data/workout_session_repository.dart';
import '../presentation/log_session_screen.dart';

/// On cold start, if the local cache still holds a session with no
/// [WorkoutSession.finishedAt] — e.g. the OS killed the app mid-workout while
/// it was backgrounded — jumps straight back into [LogSessionScreen] for it,
/// instead of leaving the user stranded on the dashboard needing to re-enter
/// it manually.
///
/// This provider is a singleton for the app's lifetime, so it only ever runs
/// once per process: a normal background/foreground cycle where the process
/// survives (LogSessionScreen still sits on top of the nav stack) never
/// rebuilds it, so it never fires a second, redundant push.
class WorkoutResumePrompt {
  WorkoutResumePrompt(this._ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  final Ref _ref;

  Future<void> _check() async {
    if (_ref.read(authControllerProvider).value == null) return;
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;

    final sessions =
        await _ref.read(workoutSessionRepositoryProvider).watchAll().first;
    final active = sessions.where((s) => s.inProgress).firstOrNull;
    if (active == null) return;

    await navigator.push(
      MaterialPageRoute(builder: (_) => LogSessionScreen(session: active)),
    );
  }
}

final workoutResumePromptProvider = Provider<WorkoutResumePrompt>((ref) {
  return WorkoutResumePrompt(ref);
});

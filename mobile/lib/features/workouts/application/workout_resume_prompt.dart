import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/workout_session_notifier/workout_session_notifier_service.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/auth_controller.dart';
import '../data/workout_session_repository.dart';
import '../domain/workout_session.dart';
import '../presentation/log_session_screen.dart';

Future<WorkoutSession?> _findActiveSession(Ref ref) async {
  final sessions = await ref.read(workoutSessionRepositoryProvider).watchAll().first;
  return sessions.where((s) => s.inProgress).firstOrNull;
}

/// Pushes [LogSessionScreen] for [active] via the root navigator, unless a
/// live one is already mounted (see [isLogSessionScreenOpen] — reconstructing
/// a second instance from persisted DB state would clobber any not-yet-saved
/// edits the live one is holding).
Future<void> _pushSessionScreen(NavigatorState navigator, WorkoutSession active) async {
  if (isLogSessionScreenOpen) return;
  await navigator.push(
    MaterialPageRoute(builder: (_) => LogSessionScreen(session: active)),
  );
}

/// Jumps straight to the in-progress workout session, if any — used for the
/// iOS Live Activity / Dynamic Island tap (see the `lifey://workout`
/// exception handling in `app_router.dart`) and the Android ongoing
/// notification tap (see [NotificationService.setWorkoutSessionTapHandler]),
/// both of which should reopen the running workout regardless of what screen
/// the app happens to be showing. Returns whether a session is active (and
/// thus already showing or just opened) — the router falls back to the
/// dashboard when this is false. Does nothing beyond that check if a live
/// [LogSessionScreen] is already mounted (see [isLogSessionScreenOpen]).
Future<bool> openActiveWorkoutSession(Ref ref) async {
  if (isLogSessionScreenOpen) return true;
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return false;
  final active = await _findActiveSession(ref);
  if (active == null) return false;
  await _pushSessionScreen(navigator, active);
  return true;
}

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
    // Android has no scheme-based deep link for its ongoing notification —
    // the tap is delivered as a plugin callback instead (see
    // docs/25-android-widget-ongoing-notification-plan.md). Wire it here so
    // it fires the same "reopen the active session" path as the iOS
    // Dynamic Island / Live Activity tap.
    NotificationService.setWorkoutSessionTapHandler(
      () => unawaited(openActiveWorkoutSession(_ref)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  final Ref _ref;

  Future<void> _check() async {
    if (_ref.read(authControllerProvider).value == null) return;
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;

    final active = await _findActiveSession(_ref);
    if (active == null) {
      // Safety sweep: no in-progress session survived, so any Live Activity /
      // ongoing notification still showing (e.g. the OS killed the app
      // without ever delivering a termination callback) is an orphan — end
      // it (see docs/24-ios-widget-live-activity-plan.md and
      // docs/25-android-widget-ongoing-notification-plan.md, orphan handling).
      unawaited(_ref.read(workoutSessionNotifierServiceProvider).endAll());
      return;
    }

    await _pushSessionScreen(navigator, active);
  }
}

final workoutResumePromptProvider = Provider<WorkoutResumePrompt>((ref) {
  return WorkoutResumePrompt(ref);
});

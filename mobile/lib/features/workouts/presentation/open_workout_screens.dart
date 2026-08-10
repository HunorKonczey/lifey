import 'package:flutter/material.dart';

import '../domain/workout_session.dart';
import 'log_session_screen.dart';

/// One mounted [LogSessionScreen] that is showing a **running** (unfinished)
/// session. Opened by the screen itself in `initState` and closed in
/// `dispose`; the registry below is what `workout_resume_prompt.dart` asks
/// before pushing a screen for a session.
///
/// The whole point is that this is per-screen and per-session rather than one
/// global "a screen is open" bool, which got both directions wrong:
///
/// - **Blocked the wrong pushes.** A workout started from a template creates
///   no session row until its first edit, so its screen sits there with no
///   [sessionClientId] at all. Meanwhile a workout started *on the watch*
///   creates a real running session (via `StandaloneSessionProcessor`) that
///   needs its own screen — which is also what starts its Live Activity. The
///   bool said "a screen is open", so that push was skipped: no mirror, no
///   Live Activity, and the workout only surfaced after an app restart, when
///   the cold-start sweep pushed it.
/// - **Cleared on the wrong dispose.** Any screen closing set the bool back
///   to false, including one for a *finished* session opened on top, which
///   then let a duplicate screen be pushed over a live workout — exactly what
///   the bool existed to prevent.
class OpenWorkoutScreen {
  OpenWorkoutScreen._(this.sessionClientId);

  /// The session this screen is showing, or null while it hasn't persisted
  /// one yet (a template-started workout creates its row on the first edit —
  /// see `LogSessionScreen._persist`). Assigned by the screen as soon as it
  /// knows, so a `null` here means "not this session" rather than "unknown,
  /// assume it matches".
  String? sessionClientId;
}

final List<OpenWorkoutScreen> _openScreens = [];

/// Registers a newly mounted running-session screen. [sessionClientId] may be
/// null; the caller updates [OpenWorkoutScreen.sessionClientId] once its
/// session exists.
OpenWorkoutScreen openWorkoutScreen(String? sessionClientId) {
  final screen = OpenWorkoutScreen._(sessionClientId);
  _openScreens.add(screen);
  return screen;
}

/// Unregisters [screen] (from `dispose`). Removes that screen only, never
/// anyone else's — see [OpenWorkoutScreen]'s "cleared on the wrong dispose".
void closeWorkoutScreen(OpenWorkoutScreen screen) {
  _openScreens.remove(screen);
}

/// Whether [sessionClientId] already has a live screen. Pushing a second one
/// for the *same* session is what must be avoided: a fresh instance is
/// rebuilt from the last **persisted** DB state, so any not-yet-flushed
/// in-memory edit (a weight being typed into the compact editor) would be
/// silently dropped, and the duplicate's stale state would then overwrite the
/// Live Activity / ongoing notification. A screen showing a *different*
/// session — or none yet — is no reason to skip anything.
bool isWorkoutScreenOpenFor(String sessionClientId) {
  for (final screen in _openScreens) {
    if (screen.sessionClientId == sessionClientId) return true;
  }
  return false;
}

/// Registry state is process-global, so a test that opens a screen without
/// closing it would leak into the next one.
@visibleForTesting
void resetOpenWorkoutScreens() => _openScreens.clear();

// ---------------------------------------------------------------------------
// The single kind-branch point
// ---------------------------------------------------------------------------

/// The single place that decides which screen to open for an existing
/// [session] the app already knows about — a resume, "tap to continue/edit",
/// or notification/Live-Activity-tap flow. Every such call site
/// (`sessions_tab.dart`, `dashboard_screen.dart`, `upcoming_workout_card.dart`,
/// `workout_resume_prompt.dart`, `push_tap_handler.dart`) goes through this
/// function instead of constructing a screen widget itself, so there is
/// exactly one place that has to know which screen a [session] opens into.
///
/// Deliberately **not** used for starting a fresh session from a template
/// (`LogSessionScreen(template: ...)`): templates are strength-only in V1
/// (docs/cardio/51-cardio-overview-plan.md §5 — no cardio templates yet), so
/// that path has nothing to branch on and stays a direct push at each
/// call site.
///
/// [watchMastered] and [watchCurrentExerciseIndex] are
/// [LogSessionScreen]-specific (docs/watch/44-watch-f6-standalone-plan.md) —
/// harmless no-ops for a caller that doesn't have them, kept here rather than
/// on a bespoke strength-only variant so this stays the one call site.
///
/// TODO(cardio): once [WorkoutSession] carries a `sessionKind`
/// (docs/cardio/52-cardio-domain-backend-plan.md, landing in mobile in C1.5),
/// branch on it here — `CARDIO` pushes `CardioSessionScreen` (C2),
/// `STRENGTH` (today's only value) keeps the [LogSessionScreen] push below,
/// unchanged. See docs/cardio/59-cardio-implementation-plan.md C0.4/C2.
Future<void> openSessionScreen(
  NavigatorState navigator,
  WorkoutSession session, {
  bool watchMastered = false,
  int? watchCurrentExerciseIndex,
}) {
  return navigator.push(
    MaterialPageRoute(
      builder: (_) => LogSessionScreen(
        session: session,
        watchMastered: watchMastered,
        watchCurrentExerciseIndex: watchCurrentExerciseIndex,
      ),
    ),
  );
}

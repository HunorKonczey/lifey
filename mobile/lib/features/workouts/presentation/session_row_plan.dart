import '../../../core/format/cardio_formatter.dart';
import '../../settings/domain/user_settings.dart';
import '../domain/activity_type.dart';
import '../domain/workout_session.dart';

/// How many set rows one exercise of a session should show, and what its
/// effective plan size is. Pulled out of [LogSessionScreen._rebuildBlocks] as
/// a pure function — same reason [decideWatchSetLog] lives outside the
/// screen: the rule decides whether a running workout has anywhere to log the
/// next set, so it deserves tests that don't need the whole screen mounted.
class SessionRowPlan {
  const SessionRowPlan({required this.targetSets, required this.blankRows});

  /// The plan size to carry on the rebuilt block: the session's own stored
  /// count when it has one, else the template fallback, else null ("no plan
  /// known").
  final int? targetSets;

  /// How many empty rows to append after the already-logged ones.
  final int blankRows;
}

/// Resolves [SessionRowPlan] for one exercise.
///
/// [storedTargetSets] is what the session row itself holds. It is **client-
/// only** state: the sync payload never carries it (see
/// `WorkoutSessionRepository._payload`), so a session that has been through
/// the server can legitimately come back with it null even though the user
/// planned several sets — which is why [templateTargetSets] (the count from
/// the template the session was started from) is consulted before concluding
/// there is no plan.
///
/// With no plan from either source, a **running** session still gets one
/// blank row: it's where the compact editor — and the watch's "+1 set" tap,
/// which targets the first not-done row — logs the next set. A finished
/// session gets one only when it logged nothing at all, so an old workout
/// isn't decorated with an empty row it never had.
SessionRowPlan planSessionRows({
  required int? storedTargetSets,
  required int? templateTargetSets,
  required int doneSets,
  required bool sessionFinished,
}) {
  final targetSets = storedTargetSets ?? templateTargetSets;
  final remaining = (targetSets ?? 0) - doneSets;
  if (remaining > 0) {
    return SessionRowPlan(targetSets: targetSets, blankRows: remaining);
  }
  final keepOneOpen = doneSets == 0 || (targetSets == null && !sessionFinished);
  return SessionRowPlan(targetSets: targetSets, blankRows: keepOneOpen ? 1 : 0);
}

/// The single family-dependent metric a session-list card shows for a
/// cardio session — the "cél alakú" (goal-shaped) number for DISTANCE
/// (distance, falling back to the duration when no distance was recorded,
/// e.g. a manual walk log — mirrors the "nincs távforrás" active-session
/// fallback), and the moving/playing duration for MACHINE and GAME
/// (`docs/cardio/design/Lifey Cardio Design.dc.html` §2: "a szobabicikli
/// negyven perc, nem tizennyolc kilométer"). Null only when the session has
/// neither a distance nor a duration yet (still starting), or isn't cardio.
String? cardioCardPrimaryMetric(WorkoutSession session, UnitSystem unitSystem) {
  final family = session.family;
  if (family == null) return null;
  if (family == ActivityFamily.distance) {
    final meters = session.cardio?.distanceMeters;
    if (meters != null && meters > 0) {
      return CardioFormatter.distance(meters, unitSystem);
    }
  }
  final duration = session.effectiveDuration;
  return duration == null ? null : CardioFormatter.duration(duration);
}

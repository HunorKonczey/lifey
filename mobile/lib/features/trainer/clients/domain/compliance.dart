import 'trainer_client.dart';

/// Dart port of the web's `web/src/features/trainer/compliance.ts`.
///
/// Kept deliberately line-for-line with the TypeScript original — same
/// thresholds, same fallback, same comparator tie-breaks — because the two
/// clients must order and flag the *same* client list identically
/// (docs/chat/41-trainer-mobile-v2-plan.md T1, §6 "kettős karbantartás").
/// The test file mirrors `compliance.test.ts` case for case; change one side
/// and you must change the other.

/// Flagged once a client hasn't logged anything (meal/water/workout/weight) in this many days.
const int inactivityFlagDays = 3;

/// Flagged once a client hasn't logged their weight in this many days.
const int weightStaleFlagDays = 7;

const int _msPerDay = 24 * 60 * 60 * 1000;

int _daysSince(DateTime? date, DateTime fallback, DateTime now) {
  final reference = date ?? fallback;
  final elapsedMs = now.millisecondsSinceEpoch - reference.millisecondsSinceEpoch;
  if (elapsedMs < 0) return 0;
  return elapsedMs ~/ _msPerDay;
}

class ComplianceFlags {
  const ComplianceFlags({
    required this.daysSinceLastLog,
    required this.daysSinceWeight,
    required this.missedWorkouts,
    required this.inactive,
    required this.weightStale,
    required this.hasMissedWorkouts,
  });

  final int daysSinceLastLog;
  final int daysSinceWeight;
  final int missedWorkouts;
  final bool inactive;
  final bool weightStale;
  final bool hasMissedWorkouts;

  bool get needsAttention => inactive || weightStale || hasMissedWorkouts;
}

/// Raw facts (lastActivityAt/lastWeightAt/missedWorkoutCount) come from the
/// backend; thresholds and flag composition live here so the client card, the
/// "needs attention" section and sorting all agree (docs/29).
///
/// Brand-new clients fall back to `activeSince` for both "days since" figures
/// — a client who never logged anything only gets flagged once the threshold
/// has passed since they joined, not immediately on invite acceptance.
ComplianceFlags complianceFor(TrainerClient client, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final daysSinceLastLog = _daysSince(client.lastActivityAt, client.activeSince, at);
  final daysSinceWeight = _daysSince(client.lastWeightAt, client.activeSince, at);
  final missedWorkouts = client.missedWorkoutCount;

  return ComplianceFlags(
    daysSinceLastLog: daysSinceLastLog,
    daysSinceWeight: daysSinceWeight,
    missedWorkouts: missedWorkouts,
    inactive: daysSinceLastLog >= inactivityFlagDays,
    weightStale: daysSinceWeight >= weightStaleFlagDays,
    hasMissedWorkouts: missedWorkouts >= 1,
  );
}

/// Least-active-first: worst inactivity, then most missed workouts.
int byLeastActiveFirst(TrainerClient a, TrainerClient b, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final flagsA = complianceFor(a, now: at);
  final flagsB = complianceFor(b, now: at);
  final byInactivity = flagsB.daysSinceLastLog - flagsA.daysSinceLastLog;
  if (byInactivity != 0) return byInactivity;
  return flagsB.missedWorkouts - flagsA.missedWorkouts;
}

/// Most missed workouts first.
int byMostMissedWorkouts(TrainerClient a, TrainerClient b) =>
    b.missedWorkoutCount - a.missedWorkoutCount;

/// Weight overdue first.
int byWeightOverdue(TrainerClient a, TrainerClient b, {DateTime? now}) {
  final at = now ?? DateTime.now();
  return complianceFor(b, now: at).daysSinceWeight -
      complianceFor(a, now: at).daysSinceWeight;
}

/// `recent` keeps the backend's default order (respondedAt desc) — no re-sort.
enum ClientSortOption { recent, leastActive, mostMissed, weightOverdue }

/// Applies a [ClientSortOption] to an already-fetched client list — pure, no
/// API params, and never mutates [clients].
List<TrainerClient> sortClients(
  List<TrainerClient> clients,
  ClientSortOption sort, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  switch (sort) {
    case ClientSortOption.leastActive:
      return [...clients]..sort((a, b) => byLeastActiveFirst(a, b, now: at));
    case ClientSortOption.mostMissed:
      return [...clients]..sort(byMostMissedWorkouts);
    case ClientSortOption.weightOverdue:
      return [...clients]..sort((a, b) => byWeightOverdue(a, b, now: at));
    case ClientSortOption.recent:
      return clients;
  }
}

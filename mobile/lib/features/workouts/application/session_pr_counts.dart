import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cardio_personal_record.dart';
import '../domain/personal_record.dart';
import '../domain/workout_session.dart';
import 'workout_session_controller.dart';

/// How many personal records each finished session set at the time — the
/// "🏆 2 PRs" chip of the Sessions list (docs/redesign/77-mobile-redesign-plan.md
/// R3.2). Keyed by the session's `clientId`; a session without a record has no
/// entry.
///
/// Derived, never stored, like every other PR: the sessions are replayed
/// oldest to newest, so a record is judged against what came *before* the
/// session (and, for strength, against the earlier sets of the same session),
/// which makes editing an old session re-judge everything after it.
///
/// Strength: one per (exercise, [PrType]) pair — a bench press that set a
/// heaviest weight *and* an estimated 1RM is two, three heavy sets in a row
/// that each beat the last are still one "heaviest set". Cardio: one per
/// [CardioPrType] the session broke. An in-progress session has none yet.
Map<String, int> computeSessionPrCounts(List<WorkoutSession> sessions) {
  final finished = sessions
      .where((s) => !s.isUpcoming && s.startedAt != null && s.finishedAt != null)
      .toList()
    ..sort((a, b) => a.startedAt!.compareTo(b.startedAt!));

  final baselines = <String, PrBaseline>{}; // by exercise clientId
  var cardioBaseline = CardioPrBaseline.empty;
  final counts = <String, int>{};

  for (final session in finished) {
    var count = 0;
    if (session.isCardio) {
      count = detectCardioPrs(cardioBaseline, session).length;
      cardioBaseline = cardioBaseline.extend(session);
    } else {
      final byExercise = <String, List<PrSet>>{};
      for (final set in session.sets) {
        byExercise
            .putIfAbsent(set.exerciseClientId, () => [])
            .add((weight: set.weight, reps: set.reps, performedAt: set.performedAt));
      }
      for (final entry in byExercise.entries) {
        final sets = entry.value..sort((a, b) => a.performedAt.compareTo(b.performedAt));
        var baseline = baselines[entry.key] ?? PrBaseline.empty;
        final types = <PrType>{};
        for (final found in detectPrsInOrder(baseline, sets)) {
          types.addAll(found);
        }
        count += types.length;
        for (final set in sets) {
          baseline = baseline.extend(set);
        }
        baselines[entry.key] = baseline;
      }
    }
    if (count > 0) counts[session.clientId] = count;
  }
  return counts;
}

/// [computeSessionPrCounts] over the whole cached history, recomputed only
/// when the sessions change — once per list build, not once per row.
final sessionPrCountsProvider = Provider<Map<String, int>>((ref) {
  final sessions = ref.watch(workoutSessionControllerProvider).value;
  if (sessions == null) return const {};
  return computeSessionPrCounts(sessions);
});

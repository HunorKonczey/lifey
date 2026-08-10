import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/workout_session.dart';
import '../domain/workout_template.dart';
import 'workout_session_controller.dart';
import 'workout_template_controller.dart';

/// Looks for a repeating cycle in the templates used across [sessionsDesc]
/// (newest first, as returned by [WorkoutSessionController]) and predicts
/// the clientId of the template that continues it.
///
/// Unfinished sessions (started but not yet completed) are excluded first,
/// so a workout still in progress doesn't skew the detected pattern.
/// Sessions with no template — a freeform strength start today, and every
/// cardio session once those exist (docs/cardio/51-cardio-overview-plan.md
/// §1.1: cardio has no templates in V1) — are filtered out **before** taking
/// the most recent 10, not after: they carry no template-cycle signal, so
/// letting them each consume a "recent" slot would just shrink the window
/// the cycle detector actually gets to look at (docs/cardio/56, risk S11).
/// Only the most recent 10 *templated* sessions are considered, so a routine
/// change a few weeks ago doesn't keep influencing today's suggestion.
/// Returns null when there's too little history or no exact repeating
/// pattern — no recommendation is better than a wrong one.
String? predictNextTemplateClientId(List<WorkoutSession> sessionsDesc) {
  final seq = sessionsDesc
      .where((s) => !s.inProgress)
      .map((s) => s.templateClientId)
      .whereType<String>()
      .take(10)
      .toList()
      .reversed
      .toList();
  if (seq.length < 2) return null;

  for (var period = 1; period <= seq.length ~/ 2; period++) {
    var matches = true;
    for (var i = period; i < seq.length; i++) {
      if (seq[i] != seq[i - period]) {
        matches = false;
        break;
      }
    }
    if (matches) return seq[seq.length - period];
  }
  return null;
}

/// The template recommended to start next, or null when there isn't enough
/// history/pattern to suggest one, or the predicted template was deleted.
final recommendedTemplateProvider = Provider<WorkoutTemplate?>((ref) {
  final sessions = ref.watch(workoutSessionControllerProvider).value ?? const [];
  final templates = ref.watch(workoutTemplateControllerProvider).value ?? const [];
  final predictedId = predictNextTemplateClientId(sessions);
  if (predictedId == null) return null;
  for (final t in templates) {
    if (t.clientId == predictedId) return t;
  }
  return null;
});

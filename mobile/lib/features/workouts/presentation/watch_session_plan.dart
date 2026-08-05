import 'dart:convert';

import '../application/watch_template_sync.dart';
import 'widgets/exercise_session_card.dart';

/// One exercise of the **live session** as the watch receives it
/// (docs/watch/50-watch-f6c-session-plan-sync-plan.md).
///
/// Deliberately the same shape as [WatchTemplateExercisePayload] — the watch
/// decodes both into the same struct, so everything already built on a synced
/// template's exercise (the list screen, the rest length, the stepper prefill)
/// works unchanged when the list comes from the session instead. The one
/// addition is [setsDone]: a template has no such thing, but the phone's row
/// is the only place both devices' sets meet, so the plan is the natural place
/// to answer it.
///
/// [exerciseId] is the exercise's **clientId**, exactly as
/// [WatchTemplateExercisePayload.exerciseId] already carries it. That id — not
/// a position — is what the watch sends back with each logged set from now on,
/// which is what makes the list free to change mid-session.
class WatchSessionPlanExercise {
  const WatchSessionPlanExercise({
    required this.exerciseId,
    required this.name,
    required this.restSeconds,
    required this.setsDone,
    this.targetSets,
    this.previousSets = const [],
  });

  final String exerciseId;
  final String name;
  final int restSeconds;

  /// How many sets this session already has for the exercise, counting both
  /// devices' — the watch takes the larger of this and its own count, the same
  /// reconciliation `setsDonePerExercise` got before this existed.
  final int setsDone;

  /// The session's **live** row count (what the phone's own card shows), not
  /// the template's frozen plan number: "+ Add set" and a removed row both
  /// move it, and the watch's "N of M" has to agree with the screen the user
  /// is looking at. Null for a block with no rows at all, which would
  /// otherwise read as "complete" on the wrist.
  final int? targetSets;

  final List<WatchPreviousSetPayload> previousSets;

  Map<String, Object?> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'restSeconds': restSeconds,
        'setsDone': setsDone,
        if (targetSets != null) 'targetSets': targetSets,
        if (previousSets.isNotEmpty)
          'previousSets': [for (final set in previousSets) set.toJson()],
      };
}

/// The session's current exercise list, JSON-encoded for the watch — null when
/// there's nothing to send (no blocks).
///
/// **A JSON string rather than a nested map/list** because this rides inside
/// the session-state payload, and that payload's Wear transport (`WatchBridge
/// .kt`'s `toDataMap()`, used for the DataItem resync path) carries only flat
/// scalars and int lists. A string survives every transport unchanged — the
/// message path, the DataItem path, and iOS's property-list `applicationContext`
/// — and both watch apps already decode template JSON, so this reuses a decoder
/// instead of adding a transport shape.
///
/// [restSecondsFor] is the phone's own per-exercise resolution
/// (`LogSessionScreen._effectiveRestSeconds`: the exercise's override, else the
/// account default), passed in so this stays a pure function.
String? buildWatchSessionPlanJson({
  required List<ExerciseBlock> blocks,
  required int Function(ExerciseBlock block) restSecondsFor,
}) {
  if (blocks.isEmpty) return null;
  final exercises = [
    for (final block in blocks)
      WatchSessionPlanExercise(
        exerciseId: block.exerciseClientId,
        name: block.exerciseName,
        restSeconds: restSecondsFor(block),
        setsDone: block.rows.where((r) => r.isDone).length,
        targetSets: block.rows.isEmpty ? null : block.rows.length,
        previousSets: [
          for (final hint in block.previousSets)
            WatchPreviousSetPayload(weight: hint.weight, reps: hint.reps),
        ],
      ),
  ];
  return jsonEncode({
    'exercises': [for (final exercise in exercises) exercise.toJson()],
  });
}

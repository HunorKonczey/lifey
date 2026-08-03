import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../domain/exercise.dart';
import '../domain/workout_session.dart';
import '../domain/workout_template.dart';
import 'exercise_controller.dart';
import 'workout_session_controller.dart';
import 'workout_template_controller.dart';

/// At most this many templates go over the wire (docs/watch/
/// 49-watch-f6b-template-sync-plan.md D-F6b.1) — the picker's own limit, and
/// the reason [recentlyUsedTemplateClientIds] needs a recency order at all.
const watchTemplateSyncMaxTemplates = 5;

/// At most this many exercises per template (D-F6b.6) — a rule-of-thumb cap
/// on payload size and picker render cost, not a measured limit. A longer
/// template is **truncated, not dropped**: a 20-exercise plan is still worth
/// offering, and the picker's `standalone_plan_exercises` count then reports
/// the truncated length, which is what the watch actually holds.
const watchTemplateSyncMaxExercisesPerTemplate = 12;

/// The clientIds of the templates the user started most recently, newest
/// first, for the watch's standalone picker (docs/watch/
/// 49-watch-f6b-template-sync-plan.md D-F6b.1).
///
/// "Most recent" deliberately means *last used*, not *last created/edited*:
/// the `workout_templates` table carries no timestamp column at all, so
/// session history is the only ordering signal that exists. [sessionsDesc]
/// is newest-first, as [WorkoutSessionController] returns it — the same
/// input [predictNextTemplateClientId] reads, so this adds no new query.
///
/// Accepted limitation (D-F6b.1): a template the user created but has never
/// actually started never appears here, because there is nothing to order it
/// by. The picker's "Quick strength" card stays available regardless, so a
/// brand-new template is never a dead end — the user starts it once from the
/// phone and it shows up from then on.
///
/// Sessions still in progress are skipped, matching
/// [predictNextTemplateClientId]'s own filter: a workout the user is running
/// right now shouldn't reorder the list mid-session.
List<String> recentlyUsedTemplateClientIds(
  List<WorkoutSession> sessionsDesc, {
  int max = 5,
}) {
  final ids = <String>{};
  for (final session in sessionsDesc) {
    if (session.inProgress) continue;
    final templateClientId = session.templateClientId;
    if (templateClientId == null) continue;
    ids.add(templateClientId);
    if (ids.length == max) break;
  }
  return ids.toList();
}

/// At most this many previous sets per exercise (see
/// [WatchTemplateExercisePayload.previousSets]) — the watch pairs them
/// positionally with the sets it logs, and nobody plans past this many
/// working sets of one exercise; the cap just keeps the payload bounded when
/// 5 templates × 12 exercises all carry history.
const watchTemplateSyncMaxPreviousSets = 6;

/// One set from the last time this exercise was trained, as the watch
/// receives it — the watch's stand-in for the `nextSetReps`/`nextSetWeight`
/// prefill a phone-mastered session gets pushed on every state sync
/// (docs/watch/48-watch-f5b-set-adjust-plan.md D-F5b.2). A standalone session
/// has no phone driving it, so without this the watch could only ever open
/// its stepper on a hardcoded default and log "10 reps, no weight".
class WatchPreviousSetPayload {
  const WatchPreviousSetPayload({required this.weight, required this.reps});

  final double weight;
  final int reps;

  Map<String, Object?> toJson() => {'weight': weight, 'reps': reps};
}

/// One exercise of a template as the watch receives it (docs/watch/
/// 49-watch-f6b-template-sync-plan.md §4.1).
///
/// [restSeconds] is **already resolved** here, never nullable: the watch
/// knows neither the `Exercises` table nor `UserSettings`, so it could not
/// fall back on its own (D-F6b.4). [exerciseId] is carried so a future
/// change can key off it, but the watch only ever sends back this entry's
/// *position* in the list (`exerciseIndex`, 44-doc §4.1) — that keeps the
/// standalone-session payload small.
class WatchTemplateExercisePayload {
  const WatchTemplateExercisePayload({
    required this.exerciseId,
    required this.name,
    required this.restSeconds,
    this.targetSets,
    this.previousSets = const [],
  });

  final String exerciseId;
  final String name;
  final int restSeconds;
  final int? targetSets;

  /// What was logged for this exercise the last time it was trained, heaviest
  /// first — the same list, resolved the same way, that
  /// [WorkoutSessionRepository.getPreviousPerformance] gives the phone's own
  /// session screen. Empty when this exercise has no history yet. The watch
  /// pairs it positionally with the sets it logs, so entry *n* is the default
  /// for that exercise's *n*-th set of the session.
  final List<WatchPreviousSetPayload> previousSets;

  /// Omits [targetSets] when null rather than sending an explicit null —
  /// matches how both native bridges treat absent values (`WatchBridge.kt`'s
  /// `toDataMap()` and `WatchBridge.swift`'s `sanitizedForPropertyList`
  /// strip nulls outright, so a null would be dropped in transit anyway.
  /// [previousSets] is omitted when empty for the same reason it would be
  /// pointless to send: the watch's own decoder defaults it to empty.
  Map<String, Object?> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'restSeconds': restSeconds,
        if (targetSets != null) 'targetSets': targetSets,
        if (previousSets.isNotEmpty)
          'previousSets': [for (final set in previousSets) set.toJson()],
      };
}

/// One template as the watch receives it (§4.1) — enough to render a picker
/// row and drive a plan-backed standalone session, nothing more.
class WatchTemplatePayload {
  const WatchTemplatePayload({
    required this.templateId,
    required this.title,
    required this.exercises,
  });

  final String templateId;
  final String title;
  final List<WatchTemplateExercisePayload> exercises;

  Map<String, Object?> toJson() => {
        'templateId': templateId,
        'title': title,
        'exercises': [for (final exercise in exercises) exercise.toJson()],
      };
}

/// Builds the `templateSync` payload the phone pushes to the watch
/// (docs/watch/49-watch-f6b-template-sync-plan.md §4.1, T1.2).
///
/// Takes finished data rather than repositories — like
/// [StandaloneSessionProcessor]'s plain-constructor injection, so the whole
/// resolve-and-truncate step is unit-testable without a database.
/// [templateClientIds] comes from [recentlyUsedTemplateClientIds] and defines
/// the **output order**; [templates] is the unordered (alphabetical) set the
/// repository watches, looked up by clientId.
///
/// Three things are dropped silently, all of them normal rather than
/// exceptional:
/// - an id with no matching template (deleted since it was last used — its
///   sessions still reference it, so [recentlyUsedTemplateClientIds] keeps
///   returning it);
/// - an exercise missing from [exercises] (most likely a delete in flight:
///   `ExerciseRepository.watchAll` already filters those out);
/// - a template left with no exercises at all — starting a plan with nothing
///   in it is a dead end on the watch, and the picker's "Quick strength"
///   card covers that case better.
/// [sessionsDesc] is the same newest-first list [recentlyUsedTemplateClientIds]
/// reads, reused here to resolve each exercise's
/// [WatchTemplateExercisePayload.previousSets] — deliberately from data the
/// caller already holds rather than by calling
/// [WorkoutSessionRepository.getPreviousPerformance] per exercise, which
/// would be up to 60 queries on every one of this payload's four reactive
/// triggers.
List<WatchTemplatePayload> buildWatchTemplateSync({
  required List<String> templateClientIds,
  required List<WorkoutTemplate> templates,
  required List<Exercise> exercises,
  required UserSettings settings,
  List<WorkoutSession> sessionsDesc = const [],
  int maxTemplates = watchTemplateSyncMaxTemplates,
  int maxExercisesPerTemplate = watchTemplateSyncMaxExercisesPerTemplate,
  int maxPreviousSets = watchTemplateSyncMaxPreviousSets,
}) {
  final templatesById = {for (final template in templates) template.clientId: template};
  final exercisesById = {for (final exercise in exercises) exercise.clientId: exercise};

  final payloads = <WatchTemplatePayload>[];
  for (final templateClientId in templateClientIds) {
    if (payloads.length == maxTemplates) break;
    final template = templatesById[templateClientId];
    if (template == null) continue;

    final exercisePayloads = <WatchTemplateExercisePayload>[];
    for (final templateExercise in template.exercises) {
      if (exercisePayloads.length == maxExercisesPerTemplate) break;
      final exercise = exercisesById[templateExercise.exerciseClientId];
      if (exercise == null) continue;
      exercisePayloads.add(
        WatchTemplateExercisePayload(
          exerciseId: exercise.clientId,
          name: exercise.name,
          // The same resolution LogSessionScreen._effectiveRestSeconds does
          // (docs/39-rest-timer-plan.md §2.2): per-exercise override first,
          // account-wide default otherwise.
          restSeconds: exercise.defaultRestSeconds ?? settings.defaultRestSeconds,
          targetSets: templateExercise.targetSets,
          previousSets: previousSetsFor(
            exerciseClientId: exercise.clientId,
            templateClientId: template.clientId,
            sessionsDesc: sessionsDesc,
            max: maxPreviousSets,
          ),
        ),
      );
    }
    if (exercisePayloads.isEmpty) continue;

    payloads.add(
      WatchTemplatePayload(
        templateId: template.clientId,
        title: template.name,
        exercises: exercisePayloads,
      ),
    );
  }
  return payloads;
}

/// The last session's sets for [exerciseClientId], heaviest first — a
/// pure-Dart restatement of [WorkoutSessionRepository.getPreviousPerformance]
/// over an already-loaded session list, and deliberately rule-for-rule
/// identical to it so the watch's prefill and the phone's own can't drift
/// apart: prefer the most recent session started from the same template, fall
/// back to the most recent session with this exercise under any template, and
/// sort by weight descending so callers can pair the result positionally with
/// their own set rows.
///
/// Sessions still in progress are skipped — the workout being logged right
/// now (quite possibly the very one asking for this) is not its own history.
List<WatchPreviousSetPayload> previousSetsFor({
  required String exerciseClientId,
  required String? templateClientId,
  required List<WorkoutSession> sessionsDesc,
  int max = watchTemplateSyncMaxPreviousSets,
}) {
  List<ExerciseSet> lastSessionSets({required bool scopedToTemplate}) {
    for (final session in sessionsDesc) {
      if (session.inProgress) continue;
      if (scopedToTemplate && session.templateClientId != templateClientId) continue;
      final sets = [
        for (final set in session.sets)
          if (set.exerciseClientId == exerciseClientId) set,
      ];
      if (sets.isNotEmpty) return sets;
    }
    return const [];
  }

  var sets = templateClientId == null
      ? const <ExerciseSet>[]
      : lastSessionSets(scopedToTemplate: true);
  if (sets.isEmpty) sets = lastSessionSets(scopedToTemplate: false);
  if (sets.isEmpty) return const [];

  final sorted = [...sets]..sort((a, b) => b.weight.compareTo(a.weight));
  return [
    for (final set in sorted.take(max))
      WatchPreviousSetPayload(weight: set.weight, reps: set.reps),
  ];
}

/// What the watch's standalone picker should currently hold (docs/watch/
/// 49-watch-f6b-template-sync-plan.md T2.1) — derived state only, with no
/// side effects: `WatchTemplateSyncController` is what actually pushes it.
///
/// Deliberately reactive rather than a set of hand-placed calls in the
/// template mutations (§12/T2): the payload depends on four independent
/// sources, and *every* one of them can change without a template being
/// saved — an exercise rename moves `name`, the rest setting moves
/// `restSeconds`, a finished workout reorders the list (D-F6b.1), and a
/// server pull can rewrite templates outright. Watching the data beats
/// remembering every call site that touches it.
///
/// **Null means "don't know yet, push nothing"; an empty list means "the
/// watch should hold nothing".** The distinction matters: at cold start
/// every source is still loading, and collapsing that to an empty list would
/// order the watch to wipe a perfectly good cache moments before the real
/// list arrives. Only these say "clear it", and both are real answers:
/// - `watchWorkoutEnabled` is off — the single gate for all watch traffic,
///   so leaving stale plans on the watch would be wrong;
/// - the sources loaded and there genuinely are no templates to offer.
final watchTemplateSyncPayloadProvider = Provider<List<WatchTemplatePayload>?>((ref) {
  final settingsState = ref.watch(settingsControllerProvider);
  if (settingsState.isLoading) return null;
  final settings = settingsState.value;
  if (settings == null) return null;
  if (!settings.watchWorkoutEnabled) return const [];

  final sessions = ref.watch(workoutSessionControllerProvider).value;
  final templates = ref.watch(workoutTemplateControllerProvider).value;
  final exercises = ref.watch(exerciseControllerProvider).value;
  if (sessions == null || templates == null || exercises == null) return null;

  return buildWatchTemplateSync(
    templateClientIds: recentlyUsedTemplateClientIds(sessions),
    templates: templates,
    exercises: exercises,
    settings: settings,
    sessionsDesc: sessions,
  );
});

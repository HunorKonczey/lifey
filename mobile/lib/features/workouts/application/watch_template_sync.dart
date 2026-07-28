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
  });

  final String exerciseId;
  final String name;
  final int restSeconds;
  final int? targetSets;

  /// Omits [targetSets] when null rather than sending an explicit null —
  /// matches how both native bridges treat absent values (`WatchBridge.kt`'s
  /// `toDataMap()` and `WatchBridge.swift`'s `sanitizedForPropertyList`
  /// strip nulls outright, so a null would be dropped in transit anyway).
  Map<String, Object?> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'restSeconds': restSeconds,
        if (targetSets != null) 'targetSets': targetSets,
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
List<WatchTemplatePayload> buildWatchTemplateSync({
  required List<String> templateClientIds,
  required List<WorkoutTemplate> templates,
  required List<Exercise> exercises,
  required UserSettings settings,
  int maxTemplates = watchTemplateSyncMaxTemplates,
  int maxExercisesPerTemplate = watchTemplateSyncMaxExercisesPerTemplate,
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
/// Yields an empty list — same as "the user has no templates" — in two
/// cases, both of which correctly tell the watch to clear its cache:
/// - `watchWorkoutEnabled` is off, the single gate for all watch traffic;
/// - any source is still loading, so a half-built payload is never sent.
final watchTemplateSyncPayloadProvider = Provider<List<WatchTemplatePayload>>((ref) {
  final settings = ref.watch(settingsControllerProvider).value;
  if (settings == null || !settings.watchWorkoutEnabled) return const [];

  final sessions = ref.watch(workoutSessionControllerProvider).value;
  final templates = ref.watch(workoutTemplateControllerProvider).value;
  final exercises = ref.watch(exerciseControllerProvider).value;
  if (sessions == null || templates == null || exercises == null) return const [];

  return buildWatchTemplateSync(
    templateClientIds: recentlyUsedTemplateClientIds(sessions),
    templates: templates,
    exercises: exercises,
    settings: settings,
  );
});

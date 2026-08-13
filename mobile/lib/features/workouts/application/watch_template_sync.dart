import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../domain/activity_type.dart';
import '../domain/exercise.dart';
import '../domain/workout_session.dart';
import '../domain/workout_template.dart';
import 'activity_ranking.dart';
import 'exercise_controller.dart';
import 'workout_session_controller.dart';
import 'workout_template_controller.dart';

/// At most this many templates go over the wire in one [buildWatchTemplateSync]
/// call — still the default for that function on its own (docs/watch/
/// 49-watch-f6b-template-sync-plan.md D-F6b.1), but no longer what caps the
/// unified quick-start payload (docs/cardio/55-cardio-watch-plan.md §3.2:
/// "Max 8 elem... az F6b 5-ös terv-limitje helyett") — see
/// [watchQuickStartMaxEntries].
const watchTemplateSyncMaxTemplates = 5;

/// At most this many exercises per template (D-F6b.6) — a rule-of-thumb cap
/// on payload size and picker render cost, not a measured limit. A longer
/// template is **truncated, not dropped**: a 20-exercise plan is still worth
/// offering, and the picker's `standalone_plan_exercises` count then reports
/// the truncated length, which is what the watch actually holds.
const watchTemplateSyncMaxExercisesPerTemplate = 12;

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

/// Resolves a set of template ids into full watch-ready payloads, in the
/// order given (docs/watch/49-watch-f6b-template-sync-plan.md §4.1, T1.2).
///
/// Takes finished data rather than repositories — like
/// [StandaloneSessionProcessor]'s plain-constructor injection, so the whole
/// resolve-and-truncate step is unit-testable without a database.
/// [templateClientIds] defines the **output order** — since C5.3
/// ([buildWatchQuickStartEntries]) that's [rankQuickStartEntries]'s ranking,
/// not a separate recency-only pass this function used to be paired with;
/// [templates] is the unordered (alphabetical) set the repository watches,
/// looked up by clientId.
///
/// Three things are dropped silently, all of them normal rather than
/// exceptional:
/// - an id with no matching template (deleted since it was last ranked — its
///   sessions still reference it, so [rankQuickStartEntries] keeps returning
///   it);
/// - an exercise missing from [exercises] (most likely a delete in flight:
///   `ExerciseRepository.watchAll` already filters those out);
/// - a template left with no exercises at all — starting a plan with nothing
///   in it is a dead end on the watch, and the picker's "Quick strength"
///   card covers that case better.
/// [sessionsDesc] is reused here to resolve each exercise's
/// [WatchTemplateExercisePayload.previousSets] — deliberately from data the
/// caller already holds rather than by calling
/// [WorkoutSessionRepository.getPreviousPerformance] per exercise, which
/// would be up to 60 queries on every one of this payload's reactive
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

/// At most this many entries go over the wire in the unified quick-start
/// payload (docs/cardio/55-cardio-watch-plan.md §3.2) — replaces
/// [watchTemplateSyncMaxTemplates] as *this* payload's cap: "az óra natívan
/// görgethető, tehát ez scope-döntés, nem UI-korlát" (the watch scrolls
/// natively, so this is a scope call, not a UI limit), the same reasoning
/// D-F6b.1 gave for the old 5.
const watchQuickStartMaxEntries = 8;

/// One row of the watch's unified quick-start picker (docs/cardio/
/// 55-cardio-watch-plan.md §3, C5.3) — either a specific strength template,
/// carrying the same full plan data [WatchTemplatePayload] always did (the
/// watch still needs it to actually *run* a standalone plan-backed session),
/// or a cardio activity type, which needs nothing beyond its label — there's
/// no plan to carry, and W-8 (standalone cardio, C5.7+) is what teaches the
/// watch to start one from just the type.
///
/// The freeform "Quick strength" bucket ([QuickStartEntry.strength] with a
/// null id) never turns into one of these: D-C5.3 keeps it as its own
/// permanently pinned card above this list, so [buildWatchQuickStartEntries]
/// filters it out before this class is ever built.
sealed class WatchQuickStartEntryPayload {
  const WatchQuickStartEntryPayload();

  Map<String, Object?> toJson();
}

class WatchQuickStartTemplateEntry extends WatchQuickStartEntryPayload {
  const WatchQuickStartTemplateEntry(this.template);

  final WatchTemplatePayload template;

  /// `exerciseCount` is redundant with `exercises.length` but saves the
  /// watch's picker row from unpacking the whole exercise list (with its
  /// `previousSets`) just to show a count — the same reasoning
  /// [WatchTemplateExercisePayload.restSeconds] already pre-resolves
  /// something the watch could technically derive itself.
  @override
  Map<String, Object?> toJson() => {
        'type': 'TEMPLATE',
        'templateId': template.templateId,
        'title': template.title,
        'exerciseCount': template.exercises.length,
        'exercises': [for (final exercise in template.exercises) exercise.toJson()],
      };
}

class WatchQuickStartCardioEntry extends WatchQuickStartEntryPayload {
  const WatchQuickStartCardioEntry({required this.activityType, required this.title});

  /// One of [kActivityTypes].
  final String activityType;

  /// Pre-localized on the phone (docs/cardio/55-cardio-watch-plan.md §3.2)
  /// — the watch needs no activity-type dictionary of its own, same as the
  /// template title already was.
  final String title;

  @override
  Map<String, Object?> toJson() => {
        'type': 'CARDIO',
        'activityType': activityType,
        'title': title,
      };
}

/// Builds the unified, frequency-ranked quick-start payload
/// (docs/cardio/55-cardio-watch-plan.md §3, C5.3) — the **single** source of
/// ranking is [rankQuickStartEntries] (D-C5.3's §3.1: "nem másol logikát, és
/// nem talál ki saját rendezést"), the exact function the phone's own
/// quick-start sheet and app-shortcut updater already call; this only adds
/// the watch-specific resolve/localize/serialize step on top.
///
/// Ranked with `max: watchQuickStartMaxEntries + 1` headroom before the
/// freeform-strength filter, not `watchQuickStartMaxEntries` itself — the
/// freeform bucket ([QuickStartEntry.strength] with a null id) is at most
/// one key in the whole ranking, so the one extra slot guarantees a full
/// [watchQuickStartMaxEntries] real entries survive the filter whenever that
/// many actually exist, instead of coming up one short whenever freeform
/// happened to rank inside the original window.
///
/// A named template that no longer resolves (deleted since it was ranked) is
/// dropped, not replaced with a generic placeholder — see
/// [buildWatchTemplateSync]'s own doc for why a template-less row is a dead
/// end on the watch specifically (unlike the phone's quick-start sheet,
/// which can still fall back to an empty workout). The result can therefore
/// be shorter than [watchQuickStartMaxEntries] with no backfill from lower
/// ranks, matching [buildWatchTemplateSync]'s existing "dropped, not
/// replaced" convention.
List<WatchQuickStartEntryPayload> buildWatchQuickStartEntries({
  required List<WorkoutSession> sessionsDesc,
  required List<WorkoutTemplate> templates,
  required List<Exercise> exercises,
  required UserSettings settings,
  required AppLocalizations l10n,
  required DateTime now,
  int maxEntries = watchQuickStartMaxEntries,
  int maxExercisesPerTemplate = watchTemplateSyncMaxExercisesPerTemplate,
  int maxPreviousSets = watchTemplateSyncMaxPreviousSets,
}) {
  final ranked = rankQuickStartEntries(sessionsDesc, now: now, max: maxEntries + 1)
      .where((entry) => entry.isCardio || entry.templateClientId != null)
      .take(maxEntries)
      .toList();

  final templateIds = [
    for (final entry in ranked)
      if (!entry.isCardio) entry.templateClientId!,
  ];
  final resolvedTemplates = buildWatchTemplateSync(
    templateClientIds: templateIds,
    templates: templates,
    exercises: exercises,
    settings: settings,
    sessionsDesc: sessionsDesc,
    maxTemplates: templateIds.length,
    maxExercisesPerTemplate: maxExercisesPerTemplate,
    maxPreviousSets: maxPreviousSets,
  );
  final resolvedById = {for (final template in resolvedTemplates) template.templateId: template};

  return [
    for (final entry in ranked)
      if (entry.isCardio)
        WatchQuickStartCardioEntry(
          activityType: entry.activityType!,
          title: activityTypeLabel(l10n, entry.activityType!),
        )
      else if (resolvedById[entry.templateClientId] case final template?)
        WatchQuickStartTemplateEntry(template),
  ];
}

// Matches the fallback in step_goal_notifier.dart / widget_snapshot_writer.dart:
// hungarian -> hu, everything else (including "system") -> en. We don't read
// the OS locale here, only the in-app LanguagePreference.
Locale _localeFor(LanguagePreference preference) =>
    preference == LanguagePreference.hungarian ? const Locale('hu') : const Locale('en');

/// What the watch's unified quick-start picker should currently hold
/// (docs/watch/49-watch-f6b-template-sync-plan.md T2.1, extended by
/// docs/cardio/55-cardio-watch-plan.md §3 for C5.3) — derived state only,
/// with no side effects: `WatchTemplateSyncController` is what actually
/// pushes it. Kept under its original F6b name (mirrors
/// `WorkoutSessionState.kind`'s own C2.9 precedent) even though the payload
/// is no longer templates-only.
///
/// Deliberately reactive rather than a set of hand-placed calls in the
/// template mutations (§12/T2): the payload depends on five independent
/// sources now (four plus the language preference for cardio titles), and
/// *every* one of them can change without a template being saved — an
/// exercise rename moves `name`, the rest setting moves `restSeconds`, a
/// finished workout reorders the list, and a server pull can rewrite
/// templates outright. Watching the data beats remembering every call site
/// that touches it.
///
/// **Null means "don't know yet, push nothing"; an empty list means "the
/// watch should hold nothing".** The distinction matters: at cold start
/// every source is still loading, and collapsing that to an empty list would
/// order the watch to wipe a perfectly good cache moments before the real
/// list arrives. Only these say "clear it", and both are real answers:
/// - `watchWorkoutEnabled` is off — the single gate for all watch traffic,
///   so leaving stale plans on the watch would be wrong;
/// - the sources loaded and there genuinely is nothing to offer.
final watchTemplateSyncPayloadProvider = Provider<List<WatchQuickStartEntryPayload>?>((ref) {
  final settingsState = ref.watch(settingsControllerProvider);
  if (settingsState.isLoading) return null;
  final settings = settingsState.value;
  if (settings == null) return null;
  if (!settings.watchWorkoutEnabled) return const [];

  final sessions = ref.watch(workoutSessionControllerProvider).value;
  final templates = ref.watch(workoutTemplateControllerProvider).value;
  final exercises = ref.watch(exerciseControllerProvider).value;
  if (sessions == null || templates == null || exercises == null) return null;

  return buildWatchQuickStartEntries(
    sessionsDesc: sessions,
    templates: templates,
    exercises: exercises,
    settings: settings,
    l10n: lookupAppLocalizations(_localeFor(settings.language)),
    now: DateTime.now(),
  );
});

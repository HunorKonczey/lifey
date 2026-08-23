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
/// **The cap is applied to the rows that survive, not to the ranked keys.**
/// Two things are thrown away between the ranking and the payload — the
/// freeform-strength bucket (D-C5.3 keeps it as its own pinned card) and any
/// named template that no longer resolves (deleted since it was ranked;
/// `rankQuickStartEntries` still returns its id, because its sessions do) —
/// and both used to be dropped *after* the list had already been truncated
/// to [maxEntries]. A dead key therefore ate a slot and left the payload one
/// row shorter, with no backfill from lower ranks: 3 live templates behind 6
/// since-deleted ones produced **2 rows and no cardio at all**, on a watch
/// whose only other way to start a cardio session is the phone. So the
/// ranking is now requested uncapped (`max: null`) and [maxEntries] counts
/// entries actually built, which is what the watch actually renders.
///
/// That fixes starvation-by-phantom-template, not starvation as such: with
/// [maxEntries] or more *live, used* templates the ranked list is genuinely
/// all strength, and the cold-start cardio defaults still rank below every
/// one of them (see [_defaultOrder]'s "padding" rule in `activity_ranking`).
/// The picker's "all activity types" screen — fed by
/// [buildWatchAllCardioEntries], not by this ranking — is what guarantees
/// every type stays reachable from the watch regardless.
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
  final ranked = rankQuickStartEntries(sessionsDesc, now: now, max: null)
      .where((entry) => entry.isCardio || entry.templateClientId != null)
      .toList();

  final templateIds = [
    for (final entry in ranked)
      if (!entry.isCardio) entry.templateClientId!,
  ];
  // Bounded by [maxEntries], not by `templateIds.length`: the id list is now
  // the user's *whole* ranked template history, and resolving all of it would
  // mean a `previousSetsFor` scan per exercise of every template they've ever
  // trained, on every reactive trigger. `buildWatchTemplateSync` walks the
  // ids in rank order and skips the dead ones, so stopping at [maxEntries]
  // successes still resolves every template that could possibly be rendered.
  final resolvedTemplates = buildWatchTemplateSync(
    templateClientIds: templateIds,
    templates: templates,
    exercises: exercises,
    settings: settings,
    sessionsDesc: sessionsDesc,
    maxTemplates: maxEntries,
    maxExercisesPerTemplate: maxExercisesPerTemplate,
    maxPreviousSets: maxPreviousSets,
  );
  final resolvedById = {for (final template in resolvedTemplates) template.templateId: template};

  final payloads = <WatchQuickStartEntryPayload>[];
  for (final entry in ranked) {
    if (payloads.length == maxEntries) break;
    if (entry.isCardio) {
      payloads.add(
        WatchQuickStartCardioEntry(
          activityType: entry.activityType!,
          title: activityTypeLabel(l10n, entry.activityType!),
        ),
      );
    } else if (resolvedById[entry.templateClientId] case final template?) {
      payloads.add(WatchQuickStartTemplateEntry(template));
    }
  }
  return payloads;
}

/// Every cardio activity type, in [kActivityTypes] display order, each
/// pre-localized the same way a ranked cardio row already is — the watch's
/// "all activity types" screen, the answer to "a picker only ever offers
/// what the ranking happened to surface".
///
/// Deliberately **not** ranked, filtered or capped: this list is the
/// complete, stable escape hatch behind the ranked list, so a type that
/// [buildWatchQuickStartEntries] can't fit (the user has 8+ live templates
/// they train regularly) is still one extra tap away instead of unreachable
/// from the watch entirely. It costs ~7 short rows on the wire, which is why
/// it can simply travel alongside the ranked payload on every push rather
/// than needing a request/response of its own.
///
/// Reuses [WatchQuickStartCardioEntry] rather than a leaner type: the wire
/// shape a cardio row already has (`type`/`activityType`/`title`) is exactly
/// what this screen needs, and both watch apps then decode one shape, not
/// two.
List<WatchQuickStartCardioEntry> buildWatchAllCardioEntries(AppLocalizations l10n) => [
      for (final activityType in kActivityTypes)
        WatchQuickStartCardioEntry(
          activityType: activityType,
          title: activityTypeLabel(l10n, activityType),
        ),
    ];

/// One `syncTemplates` push, whole (docs/cardio/55-cardio-watch-plan.md §3.2
/// plus the all-types screen) — the ranked [entries] the picker lists, and
/// the complete [allCardio] set behind its "all activity types" row.
///
/// One object rather than two provider values because they're pushed
/// together in a single call and deduped as a unit: the two lists change for
/// different reasons (usage vs. the account's language), and splitting them
/// would mean either two round trips to the watch or a controller that has
/// to correlate two streams to build one message.
class WatchQuickStartPayload {
  const WatchQuickStartPayload({
    required this.entries,
    required this.allCardio,
    this.unitSystem = 'METRIC',
  });

  final List<WatchQuickStartEntryPayload> entries;
  final List<WatchQuickStartCardioEntry> allCardio;

  /// `'METRIC'` or `'IMPERIAL'` — the account's own setting, sent because a
  /// **watch-started** cardio session formats its distance and pace on the
  /// watch itself (there's no phone pushing pre-formatted strings into a
  /// standalone session), and a walk that reads in km on the wrist and miles
  /// on the phone is worse than either. Rides along with this payload rather
  /// than getting a channel of its own: it changes for the same reason the
  /// pre-localized titles here do — the user changed a setting — so one push
  /// carries both.
  final String unitSystem;

  Map<String, Object?> toJson() => {
        'entries': [for (final entry in entries) entry.toJson()],
        'allCardio': [for (final entry in allCardio) entry.toJson()],
        'unitSystem': unitSystem,
      };
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
/// **Null means "don't know yet, push nothing"; an empty payload means "the
/// watch should hold nothing".** The distinction matters: at cold start
/// every source is still loading, and collapsing that to an empty list would
/// order the watch to wipe a perfectly good cache moments before the real
/// list arrives. Only these say "clear it", and both are real answers:
/// - `watchWorkoutEnabled` is off — the single gate for all watch traffic,
///   so leaving stale plans on the watch would be wrong;
/// - the sources loaded and there genuinely is nothing to offer.
final watchTemplateSyncPayloadProvider = Provider<WatchQuickStartPayload?>((ref) {
  final settingsState = ref.watch(settingsControllerProvider);
  if (settingsState.isLoading) return null;
  final settings = settingsState.value;
  if (settings == null) return null;
  // Both lists cleared together — the all-types screen is as much watch
  // traffic as the ranked list is, so the one gate covers both.
  if (!settings.watchWorkoutEnabled) {
    return const WatchQuickStartPayload(entries: [], allCardio: []);
  }
  final unitSystem = settings.unitSystem == UnitSystem.imperial ? 'IMPERIAL' : 'METRIC';

  final sessions = ref.watch(workoutSessionControllerProvider).value;
  final templates = ref.watch(workoutTemplateControllerProvider).value;
  final exercises = ref.watch(exerciseControllerProvider).value;
  if (sessions == null || templates == null || exercises == null) return null;

  final l10n = lookupAppLocalizations(_localeFor(settings.language));
  return WatchQuickStartPayload(
    entries: buildWatchQuickStartEntries(
      sessionsDesc: sessions,
      templates: templates,
      exercises: exercises,
      settings: settings,
      l10n: l10n,
      now: DateTime.now(),
    ),
    allCardio: buildWatchAllCardioEntries(l10n),
    unitSystem: unitSystem,
  );
});

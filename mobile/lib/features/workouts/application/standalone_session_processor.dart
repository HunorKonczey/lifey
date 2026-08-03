import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/health/health_service.dart';
import '../../../core/watch/watch_workout_service.dart';
import '../../settings/domain/user_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../data/exercise_repository.dart';
import '../data/workout_session_repository.dart';
import '../data/workout_template_repository.dart';
import '../domain/workout_template.dart';

/// Matches [HealthService.writeStrengthWorkoutAndGetId]'s signature, narrowed
/// to just that one method — like [WidgetSnapshotWriter]'s save/update-widget
/// callbacks — so a test can inject a fixed result instead of fighting
/// `HealthService`'s internal `Platform.isAndroid` gate, which always
/// no-ops on a non-Android test host regardless of what's faked underneath.
typedef WriteHealthWorkout = Future<String?> Function({
  required DateTime start,
  required DateTime end,
  double? activeCalories,
  String? title,
});

/// Turns a finished standalone (phone-less) watch session into a normal,
/// already-*closed* [WorkoutSession] — the counterpart of
/// [WorkoutResumePrompt]'s [WatchWorkoutSummary] handling, for the F6
/// standalone flow (docs/watch/44-watch-f6-standalone-plan.md §1, §6/3).
///
/// Deliberately plain-constructor-injected (no [Ref], no `BuildContext`),
/// unlike [WorkoutResumePrompt] itself — so it's directly unit-testable with
/// fakes, the way [WidgetSnapshotWriter] is.
class StandaloneSessionProcessor {
  StandaloneSessionProcessor({
    required WorkoutSessionRepository sessionRepository,
    required ExerciseRepository exerciseRepository,
    required WorkoutTemplateRepository templateRepository,
    required WatchWorkoutService watchService,
    required WriteHealthWorkout writeHealthWorkout,
  })  : _sessionRepository = sessionRepository,
        _exerciseRepository = exerciseRepository,
        _templateRepository = templateRepository,
        _watchService = watchService,
        _writeHealthWorkout = writeHealthWorkout;

  final WorkoutSessionRepository _sessionRepository;
  final ExerciseRepository _exerciseRepository;
  final WorkoutTemplateRepository _templateRepository;
  final WatchWorkoutService _watchService;
  final WriteHealthWorkout _writeHealthWorkout;

  /// [language] resolves the session's generic exercise/title text
  /// (docs/watch/44-watch-f6-standalone-plan.md D-F6.3) — passed in rather
  /// than read internally so this stays a plain class (mirrors
  /// [WidgetSnapshotWriter.write]'s `settings` parameter).
  ///
  /// Three-way idempotent branch on [WorkoutSessionRepository
  /// .isFinishedByClientId], now that a session can arrive here having
  /// already been adopted mid-workout (live bridging — see
  /// [processAdoption]):
  /// - doesn't exist yet → [_createSession] (the original F6a/F6b path,
  ///   unchanged: creates an already-*closed* session).
  /// - exists but not finished (was adopted, this is it finishing) →
  ///   [_finishAdoptedSession] updates the existing row instead of creating
  ///   a duplicate.
  /// - exists and already finished → a retried, already-processed delivery
  ///   (the watch's own retry-until-acked, docs/watch/
  ///   44-watch-f6-standalone-plan.md §4.2, D-F6.2) — no DB write, only acks
  ///   again.
  Future<void> process(WatchStandaloneSession event, {required LanguagePreference language}) async {
    final alreadyFinished = await _sessionRepository.isFinishedByClientId(event.standaloneSessionId);
    if (alreadyFinished == null) {
      await _createSession(event, language: language);
    } else if (alreadyFinished == false) {
      await _finishAdoptedSession(event, language: language);
    }
    await _watchService.ackStandaloneSession(event.standaloneSessionId);
  }

  /// The live-bridging counterpart of [process]: a watch-started session
  /// that is still *running*, sent as soon as the phone is (or becomes)
  /// reachable so the phone can mirror it live instead of only importing it
  /// once it ends. Idempotent the same way [process] is — an already-adopted
  /// (or already-finished, if this raced behind the final event) session is
  /// left alone, only re-acked — an already-finished session's set list is
  /// authoritative and must not be reopened by a stale resend.
  ///
  /// The watch resends this snapshot after every set it logs, not just at
  /// the initial handshake (`WorkoutManager.sendAdoptionRequestIfNeeded`) —
  /// so a session that's already adopted and still running gets its set
  /// list *refreshed* here too, which is what keeps the phone's mirror in
  /// sync live instead of only catching up once the workout ends.
  Future<void> processAdoption(
    WatchStandaloneAdoption event, {
    required LanguagePreference language,
  }) async {
    final alreadyFinished = await _sessionRepository.isFinishedByClientId(event.standaloneSessionId);
    if (alreadyFinished == null) {
      await _createRunningSession(event, language: language);
    } else if (alreadyFinished == false) {
      await _refreshRunningSession(event, language: language);
    }
    await _watchService.ackAdoption(event.standaloneSessionId);
  }

  Future<void> _createSession(
    WatchStandaloneSession event, {
    required LanguagePreference language,
  }) async {
    final resolved = await _resolveExercisesAndSets(
      sessionClientId: event.standaloneSessionId,
      templateId: event.templateId,
      sets: event.sets,
      language: language,
    );
    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);
    final endedAt = DateTime.fromMillisecondsSinceEpoch(event.endedAtEpochMs, isUtc: true);

    // Android fills this in from the just-written Health Connect record;
    // iOS already sends a real HKWorkout uuid on the wire (D-F6.5).
    final healthWorkoutId = event.healthWorkoutId ??
        await _writeHealthWorkout(
          start: startedAt,
          end: endedAt,
          activeCalories: event.activeCalories,
          title: resolved.title,
        );

    await _sessionRepository.create(
      clientId: event.standaloneSessionId,
      startedAt: startedAt,
      finishedAt: endedAt,
      exercises: resolved.exercises,
      sets: resolved.sets,
      activeCalories: event.activeCalories,
      averageHeartRate: event.averageHeartRate,
      healthWorkoutId: healthWorkoutId,
      templateClientId: resolved.template?.clientId,
      templateName: resolved.title,
      rpe: event.rpe,
    );
  }

  /// Creates the **running** mirror row for a just-adopted watch session —
  /// same exercise/set resolution as [_createSession], but `finishedAt` is
  /// left null and there's no `rpe`/`healthWorkoutId` yet (the workout isn't
  /// over; those only exist once the final [WatchStandaloneSession] lands
  /// and [_finishAdoptedSession] runs).
  Future<void> _createRunningSession(
    WatchStandaloneAdoption event, {
    required LanguagePreference language,
  }) async {
    final resolved = await _resolveExercisesAndSets(
      sessionClientId: event.standaloneSessionId,
      templateId: event.templateId,
      sets: event.sets,
      language: language,
    );
    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);

    await _sessionRepository.create(
      clientId: event.standaloneSessionId,
      startedAt: startedAt,
      finishedAt: null,
      exercises: resolved.exercises,
      sets: resolved.sets,
      activeCalories: event.activeCalories,
      averageHeartRate: event.averageHeartRate,
      templateClientId: resolved.template?.clientId,
      templateName: resolved.title,
    );
  }

  /// Refreshes an already-adopted running mirror row's set list — called
  /// every time the watch resends its adoption snapshot after logging a new
  /// set (see [processAdoption]'s doc comment), so the phone's copy doesn't
  /// go stale until the workout ends. Still a running session (`finishedAt`
  /// stays null); `rpe`/`healthWorkoutId` are left untouched (`Value.absent`)
  /// since [WatchStandaloneAdoption] doesn't carry them — only the final
  /// [WatchStandaloneSession] does, via [_finishAdoptedSession].
  Future<void> _refreshRunningSession(
    WatchStandaloneAdoption event, {
    required LanguagePreference language,
  }) async {
    final resolved = await _resolveExercisesAndSets(
      sessionClientId: event.standaloneSessionId,
      templateId: event.templateId,
      sets: event.sets,
      language: language,
    );
    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);

    await _sessionRepository.update(
      event.standaloneSessionId,
      startedAt: startedAt,
      finishedAt: null,
      exercises: resolved.exercises,
      sets: resolved.sets,
      activeCalories: Value(event.activeCalories),
      averageHeartRate: Value(event.averageHeartRate),
    );
  }

  /// Turns an already-adopted running mirror row into a closed session — the
  /// [WorkoutSessionRepository.update] counterpart of [_createSession]'s
  /// `.create`, called once the final [WatchStandaloneSession] arrives for a
  /// [standaloneSessionId] that [_createRunningSession] already wrote. Reuses
  /// the exact same exercise/set resolution and re-writes the *complete*
  /// exercises/sets list (matching [update]'s own full-replace contract) —
  /// the running mirror's own resolution could differ slightly if, say, a
  /// template changed mid-workout, so this doesn't try to diff/append.
  Future<void> _finishAdoptedSession(
    WatchStandaloneSession event, {
    required LanguagePreference language,
  }) async {
    final resolved = await _resolveExercisesAndSets(
      sessionClientId: event.standaloneSessionId,
      templateId: event.templateId,
      sets: event.sets,
      language: language,
    );
    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);
    final endedAt = DateTime.fromMillisecondsSinceEpoch(event.endedAtEpochMs, isUtc: true);

    final healthWorkoutId = event.healthWorkoutId ??
        await _writeHealthWorkout(
          start: startedAt,
          end: endedAt,
          activeCalories: event.activeCalories,
          title: resolved.title,
        );

    await _sessionRepository.update(
      event.standaloneSessionId,
      startedAt: startedAt,
      finishedAt: endedAt,
      exercises: resolved.exercises,
      sets: resolved.sets,
      activeCalories: Value(event.activeCalories),
      averageHeartRate: Value(event.averageHeartRate),
      healthWorkoutId: Value(healthWorkoutId),
      rpe: Value(event.rpe),
    );
  }

  /// The exercise/set resolution shared by [_createSession],
  /// [_createRunningSession] and [_finishAdoptedSession] — [templateId]/
  /// [sets] are the fields common to both [WatchStandaloneSession] and
  /// [WatchStandaloneAdoption] (there's no shared base class, so this takes
  /// the fields directly rather than the whole event).
  Future<
      ({
        WorkoutTemplate? template,
        List<PlannedExerciseInput> exercises,
        List<ExerciseSetInput> sets,
        String title,
      })> _resolveExercisesAndSets({
    required String sessionClientId,
    required String? templateId,
    required List<WatchStandaloneSet> sets,
    required LanguagePreference language,
  }) async {
    final genericTitle = lookupAppLocalizations(_localeFor(language)).standaloneSessionTitle;

    // Resolves to the real, synced template (docs/watch/
    // 49-watch-f6b-template-sync-plan.md D-F6b.5, T5) whenever the watch
    // sent one — F6a's `templateId == null` path (and this session's own
    // fallback below) are unaffected, this is purely additive. `null` here
    // covers every unresolvable case identically: no `templateId` at all, a
    // template deleted since the watch cached it, or (via
    // [_resolvesWithinTemplate] below) an out-of-range `exerciseIndex` — all
    // of these fall all the way back to the F6a generic-exercise behavior,
    // never partially.
    final template = templateId == null ? null : await _templateRepository.findByClientId(templateId);

    // Computed once, before any exercise is created — a session can be a
    // *mix* of template-resolved and unresolved sets (e.g. the plan
    // shrank after the watch cached it), so the generic exercise is only
    // fetched/created when at least one set actually needs it, not
    // unconditionally the way F6a's single-exercise path always did.
    final needsGenericExercise =
        template == null || sets.any((set) => !_resolvesWithinTemplate(set.exerciseIndex, template));
    final genericExerciseClientId =
        needsGenericExercise ? await _exerciseRepository.getOrCreateByName(genericTitle) : null;

    final title = template?.name ?? genericTitle;

    // Which exercise each set counts against, resolved once up front: both
    // the `sets` list below and [_resolveWeights]'s per-exercise fallback
    // need it, and it must be the same answer for both.
    final setExerciseIds = [
      for (final set in sets)
        _resolvesWithinTemplate(set.exerciseIndex, template)
            ? template!.exercises[set.exerciseIndex!].exerciseClientId
            : genericExerciseClientId!,
    ];
    final weights = await _resolveWeights(
      sessionClientId: sessionClientId,
      templateClientId: template?.clientId,
      sets: sets,
      setExerciseIds: setExerciseIds,
    );

    return (
      template: template,
      // The template's *full* exercise list, not just the ones a set was
      // actually logged against — so the session looks the same on the
      // phone as the plan it was started from (§5/T5). `WorkoutSessionRepository
      // .create`/`templateClientId`/`templateName` already existed before F6b
      // (the normal in-app "start from a template" flow); F6a simply never
      // populated them.
      exercises: template != null
          ? [
              for (final exercise in template.exercises)
                PlannedExerciseInput(
                  exerciseClientId: exercise.exerciseClientId,
                  targetSets: exercise.targetSets,
                ),
            ]
          : [PlannedExerciseInput(exerciseClientId: genericExerciseClientId!)],
      sets: [
        for (var i = 0; i < sets.length; i++)
          ExerciseSetInput(
            exerciseClientId: setExerciseIds[i],
            reps: sets[i].reps,
            weight: weights[i],
            performedAt: DateTime.fromMillisecondsSinceEpoch(sets[i].loggedAtEpochMs, isUtc: true),
          ),
      ],
      title: title,
    );
  }

  /// The weight to persist for each of [sets], positionally.
  ///
  /// A plain watch "+1" tap carries **no** weight — only the adjust stepper
  /// sends one (docs/watch/48-watch-f5b-set-adjust-plan.md §4.1) — and
  /// `exercise_sets.weight` is NOT NULL, so those sets used to land as a
  /// literal 0 kg even when the exercise obviously has a working weight.
  /// This mirrors what the phone already does for the same tap on a
  /// phone-mastered session (`LogSessionScreen._handleAddSet`'s
  /// `prefillFromPrevious`), in the same priority order:
  ///
  /// 1. the positional hint from the last session that trained this exercise;
  /// 2. otherwise the working weight carried forward from an earlier set of
  ///    the same exercise in *this* session;
  /// 3. otherwise 0 — genuinely nothing to go on (bodyweight).
  ///
  /// A set that *does* carry a weight is never second-guessed, including an
  /// explicit 0 the user dialled in on the stepper.
  Future<List<double>> _resolveWeights({
    required String sessionClientId,
    required String? templateClientId,
    required List<WatchStandaloneSet> sets,
    required List<String> setExerciseIds,
  }) async {
    final needsFallback = <String>{
      for (var i = 0; i < sets.length; i++)
        if (sets[i].weight == null) setExerciseIds[i],
    };
    final hints = <String, List<PreviousSetHint>>{};
    for (final exerciseClientId in needsFallback) {
      hints[exerciseClientId] = await _sessionRepository.getPreviousPerformance(
        exerciseClientId: exerciseClientId,
        templateClientId: templateClientId,
        // The row this batch is (re)writing must not seed itself: an
        // adoption resend mid-workout would otherwise read back the weights
        // an earlier resend had already inferred, and treat its own guess as
        // history.
        excludeSessionClientId: sessionClientId,
      );
    }

    final positionByExercise = <String, int>{};
    final carriedWeight = <String, double>{};
    final weights = <double>[];
    for (var i = 0; i < sets.length; i++) {
      final exerciseClientId = setExerciseIds[i];
      // `update` returns the new value, so the first set of an exercise gets
      // position 0 — the index its hint sits at in that exercise's previous
      // performance.
      final position =
          positionByExercise.update(exerciseClientId, (value) => value + 1, ifAbsent: () => 0);
      var weight = sets[i].weight;
      if (weight == null) {
        final exerciseHints = hints[exerciseClientId] ?? const <PreviousSetHint>[];
        weight = position < exerciseHints.length
            ? exerciseHints[position].weight
            : carriedWeight[exerciseClientId];
      }
      weight ??= 0;
      carriedWeight[exerciseClientId] = weight;
      weights.add(weight);
    }
    return weights;
  }

  /// Whether [exerciseIndex] points at a real entry in [template]'s exercise
  /// list — false for a null template, a null index, or an index the plan
  /// no longer has (shrunk since the watch cached it). Every false case
  /// falls back to the generic exercise identically; this helper is what
  /// keeps that fallback condition in exactly one place instead of
  /// duplicated across the `exercises`/`sets` construction above.
  bool _resolvesWithinTemplate(int? exerciseIndex, WorkoutTemplate? template) {
    if (template == null || exerciseIndex == null) return false;
    return exerciseIndex >= 0 && exerciseIndex < template.exercises.length;
  }

  // Matches the fallback in step_goal_notifier.dart / widget_snapshot_writer.dart:
  // hungarian -> hu, everything else (including "system") -> en. We don't
  // read the OS locale here, only the in-app LanguagePreference.
  Locale _localeFor(LanguagePreference preference) =>
      preference == LanguagePreference.hungarian ? const Locale('hu') : const Locale('en');
}

final standaloneSessionProcessorProvider = Provider<StandaloneSessionProcessor>((ref) {
  return StandaloneSessionProcessor(
    sessionRepository: ref.watch(workoutSessionRepositoryProvider),
    exerciseRepository: ref.watch(exerciseRepositoryProvider),
    templateRepository: ref.watch(workoutTemplateRepositoryProvider),
    watchService: ref.watch(watchWorkoutServiceProvider),
    writeHealthWorkout: ref.watch(healthServiceProvider).writeStrengthWorkoutAndGetId,
  );
});

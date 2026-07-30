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
  /// Idempotent: a retried, already-processed [event] (same
  /// `standaloneSessionId`, the watch's own retry-until-acked delivery,
  /// docs/watch/44-watch-f6-standalone-plan.md §4.2, D-F6.2) only acks again
  /// — it never creates a second session or re-resolves the exercise.
  Future<void> process(WatchStandaloneSession event, {required LanguagePreference language}) async {
    if (!await _sessionRepository.existsByClientId(event.standaloneSessionId)) {
      await _createSession(event, language: language);
    }
    await _watchService.ackStandaloneSession(event.standaloneSessionId);
  }

  Future<void> _createSession(
    WatchStandaloneSession event, {
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
    final template =
        event.templateId == null ? null : await _templateRepository.findByClientId(event.templateId!);

    // Computed once, before any exercise is created — a session can be a
    // *mix* of template-resolved and unresolved sets (e.g. the plan
    // shrank after the watch cached it), so the generic exercise is only
    // fetched/created when at least one set actually needs it, not
    // unconditionally the way F6a's single-exercise path always did.
    final needsGenericExercise =
        template == null || event.sets.any((set) => !_resolvesWithinTemplate(set.exerciseIndex, template));
    final genericExerciseClientId =
        needsGenericExercise ? await _exerciseRepository.getOrCreateByName(genericTitle) : null;

    final title = template?.name ?? genericTitle;

    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);
    final endedAt = DateTime.fromMillisecondsSinceEpoch(event.endedAtEpochMs, isUtc: true);

    // Android fills this in from the just-written Health Connect record;
    // iOS already sends a real HKWorkout uuid on the wire (D-F6.5).
    final healthWorkoutId = event.healthWorkoutId ??
        await _writeHealthWorkout(
          start: startedAt,
          end: endedAt,
          activeCalories: event.activeCalories,
          title: title,
        );

    await _sessionRepository.create(
      clientId: event.standaloneSessionId,
      startedAt: startedAt,
      finishedAt: endedAt,
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
        for (final set in event.sets)
          ExerciseSetInput(
            exerciseClientId: _resolvesWithinTemplate(set.exerciseIndex, template)
                ? template!.exercises[set.exerciseIndex!].exerciseClientId
                : genericExerciseClientId!,
            reps: set.reps,
            weight: 0,
            performedAt: DateTime.fromMillisecondsSinceEpoch(set.loggedAtEpochMs, isUtc: true),
          ),
      ],
      activeCalories: event.activeCalories,
      averageHeartRate: event.averageHeartRate,
      healthWorkoutId: healthWorkoutId,
      templateClientId: template?.clientId,
      templateName: title,
      rpe: event.rpe,
    );
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

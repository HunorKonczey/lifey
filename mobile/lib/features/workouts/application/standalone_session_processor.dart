import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/health/health_service.dart';
import '../../../core/watch/watch_workout_service.dart';
import '../../settings/domain/user_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../data/exercise_repository.dart';
import '../data/workout_session_repository.dart';

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
    required WatchWorkoutService watchService,
    required WriteHealthWorkout writeHealthWorkout,
  })  : _sessionRepository = sessionRepository,
        _exerciseRepository = exerciseRepository,
        _watchService = watchService,
        _writeHealthWorkout = writeHealthWorkout;

  final WorkoutSessionRepository _sessionRepository;
  final ExerciseRepository _exerciseRepository;
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
    final title = lookupAppLocalizations(_localeFor(language)).standaloneSessionTitle;
    final exerciseClientId = await _exerciseRepository.getOrCreateByName(title);

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
      exercises: [PlannedExerciseInput(exerciseClientId: exerciseClientId)],
      sets: [
        for (final set in event.sets)
          ExerciseSetInput(
            exerciseClientId: exerciseClientId,
            reps: set.reps,
            weight: 0,
            performedAt: DateTime.fromMillisecondsSinceEpoch(set.loggedAtEpochMs, isUtc: true),
          ),
      ],
      activeCalories: event.activeCalories,
      averageHeartRate: event.averageHeartRate,
      healthWorkoutId: healthWorkoutId,
      templateName: title,
      rpe: event.rpe,
    );
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
    watchService: ref.watch(watchWorkoutServiceProvider),
    writeHealthWorkout: ref.watch(healthServiceProvider).writeStrengthWorkoutAndGetId,
  );
});

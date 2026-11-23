import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workouts/data/workout_session_repository.dart';
import '../../features/workouts/domain/workout_session.dart';
import 'health_cardio_workout.dart';
import 'health_preferences.dart';
import 'health_service.dart';

/// Imports finished cardio workouts from other apps as CARDIO sessions
/// (docs/integrations/89 M1, G1.5). Examples: a Garmin run synced by Garmin
/// Connect, an Apple Watch workout from another app.
///
/// - **Opt-in** (D-G5): runs only while both the general Health toggle and
///   the cardio-import toggle are on.
/// - **Cursor** (D-G5): reads from the end of the last imported workout. The
///   first run looks back [firstRunLookback].
/// - **Dedupe** (D-G3, D-G4):
///   - a record already on any local session (imported or watch-paired) is
///     skipped;
///   - Lifey's own records never reach here ([HealthService.recentCardioWorkouts]
///     filters them);
///   - a re-import of a record the user deleted gets the server's 409, and
///     the sync engine drops that local copy
///     (EntitySyncConfig.dropLocalOnCreateConflict).
/// - **Write path** (R4): every session goes through [WorkoutSessionRepository]
///   and the outbox, never raw SQL, so sync and `updated_at` behave like any
///   other session.
class CardioHealthImporter {
  CardioHealthImporter({
    required HealthPreferences prefs,
    required HealthService service,
    required WorkoutSessionRepository sessions,
    DateTime Function()? now,
  })  : _prefs = prefs,
        _service = service,
        _sessions = sessions,
        _now = now ?? DateTime.now;

  final HealthPreferences _prefs;
  final HealthService _service;
  final WorkoutSessionRepository _sessions;
  final DateTime Function() _now;

  /// How far back the very first import reaches (D-G5). Years of history in
  /// one go would flood the outbox and the statistics.
  static const firstRunLookback = Duration(days: 14);

  /// The import in flight, if any. App start and app resume can both fire
  /// within moments of each other; two overlapping runs would both see a
  /// record as new and create it twice. A second call joins the running one.
  Future<int>? _running;

  /// Runs one import and returns how many sessions it created. Best-effort:
  /// a failure (no permission, store hiccup) imports nothing and leaves the
  /// cursor where it was, so the next resume simply tries again.
  Future<int> import() => _running ??= _import().whenComplete(() => _running = null);

  Future<int> _import() async {
    try {
      if (!await _prefs.isEnabled() || !await _prefs.isCardioImportEnabled()) return 0;

      final since = await _prefs.cardioImportCursor() ?? _now().subtract(firstRunLookback);
      final workouts = await _service.recentCardioWorkouts(since: since);

      var created = 0;
      for (final workout in workouts) {
        if (!await _sessions.existsByHealthWorkoutId(workout.uuid)) {
          await _create(workout);
          created++;
        }
        // Advance after each workout, in end order, so a failure half-way
        // resumes from the first one not yet handled.
        await _prefs.setCardioImportCursor(workout.endDate);
      }
      return created;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _create(HealthCardioWorkout workout) {
    final hasMetrics = workout.distanceMeters != null || workout.steps != null;
    return _sessions.create(
      startedAt: workout.startDate,
      finishedAt: workout.endDate,
      exercises: const [],
      sets: const [],
      activeCalories: workout.activeCalories,
      averageHeartRate: workout.averageHeartRate,
      healthWorkoutId: workout.uuid,
      importSource: 'HEALTH',
      importAppName: workout.sourceName,
      sessionKind: 'CARDIO',
      activityType: workout.activityType,
      // The store has no pause data, so moving time is the whole duration.
      movingSeconds: workout.endDate.difference(workout.startDate).inSeconds,
      cardio: hasMetrics ? CardioMetrics(distanceMeters: workout.distanceMeters, steps: workout.steps) : null,
    );
  }
}

final cardioHealthImporterProvider = Provider<CardioHealthImporter>((ref) {
  return CardioHealthImporter(
    prefs: ref.watch(healthPreferencesProvider),
    service: ref.watch(healthServiceProvider),
    sessions: ref.watch(workoutSessionRepositoryProvider),
  );
});

/// Fires [CardioHealthImporter.import] once at startup and on every app
/// resume, the same lifecycle as the step and weight imports. The run right
/// after the user turns the toggle on belongs to G1.6.
class CardioImportLifecycle with WidgetsBindingObserver {
  CardioImportLifecycle(this._importer) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_importer.import());
  }

  final CardioHealthImporter _importer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_importer.import());
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

final cardioImportLifecycleProvider = Provider<CardioImportLifecycle>((ref) {
  final lifecycle = CardioImportLifecycle(ref.watch(cardioHealthImporterProvider));
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/cardio_interval_plan.dart';
import '../domain/personal_record.dart';
import '../domain/workout_session.dart';

/// One planned exercise when logging a session — clientId + optional target sets.
class PlannedExerciseInput {
  const PlannedExerciseInput({required this.exerciseClientId, this.targetSets});

  final String exerciseClientId;
  final int? targetSets;
}

/// One set to record when logging a session (request side).
class ExerciseSetInput {
  const ExerciseSetInput({
    required this.exerciseClientId,
    required this.reps,
    required this.weight,
    required this.performedAt,
  });

  final String exerciseClientId;
  final int reps;
  final double weight;
  final DateTime performedAt;
}

/// A previously logged set for an exercise, used as a hint for what to aim
/// for in the current session (see [WorkoutSessionRepository.getPreviousPerformance]).
class PreviousSetHint {
  const PreviousSetHint({required this.weight, required this.reps});

  final double weight;
  final int reps;
}

/// Local-first access to workout sessions and their planned-exercise/set
/// children. Sessions, their planned exercises and their sets are always
/// written together (see [create]/[update]), so watching just the
/// `workout_sessions` table is enough to catch every change to the whole
/// aggregate.
class WorkoutSessionRepository {
  WorkoutSessionRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  Stream<List<WorkoutSession>> watchAll() {
    final sessions$ = _db.select(_db.workoutSessions).watch();
    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(sessions$, pendingOps$, (rows, ops) => (rows, ops))
        .asyncMap((pair) async {
      final (allSessionRows, ops) = pair;
      final blocked = blockedByActiveDelete(ops);
      final sessionRows =
          allSessionRows.where((r) => !blocked.contains(r.clientId)).toList();
      if (sessionRows.isEmpty) return const <WorkoutSession>[];

      final exerciseNames = {
        for (final row in await _db.select(_db.exercises).get())
          row.clientId: row.name,
      };

      final exercisesBySession = <String, List<SessionExercise>>{};
      for (final link in await _db.select(_db.workoutSessionExercises).get()) {
        exercisesBySession.putIfAbsent(link.sessionClientId, () => []).add(
              SessionExercise(
                exerciseClientId: link.exerciseClientId,
                exerciseName: exerciseNames[link.exerciseClientId] ?? 'Unknown',
                targetSets: link.targetSets,
              ),
            );
      }

      final setsBySession = <String, List<ExerciseSet>>{};
      for (final set in await _db.select(_db.exerciseSets).get()) {
        setsBySession.putIfAbsent(set.sessionClientId, () => []).add(
              ExerciseSet(
                exerciseClientId: set.exerciseClientId,
                exerciseName: exerciseNames[set.exerciseClientId] ?? 'Unknown',
                reps: set.reps,
                weight: set.weight,
                performedAt: set.performedAt,
              ),
            );
      }
      // Rest time is a delta between consecutive sets, so each session's
      // sets must be in performedAt order before they reach the UI.
      for (final sets in setsBySession.values) {
        sets.sort((a, b) => a.performedAt.compareTo(b.performedAt));
      }

      final cardioBySession = {
        for (final row in await _db.select(_db.cardioDetails).get())
          row.sessionClientId: _cardioMetricsFromRow(row),
      };
      final splitsBySession = <String, List<CardioSplit>>{};
      for (final row in await _db.select(_db.cardioSplits).get()) {
        splitsBySession
            .putIfAbsent(row.sessionClientId, () => [])
            .add(_cardioSplitFromRow(row));
      }
      for (final splits in splitsBySession.values) {
        splits.sort((a, b) => a.splitIndex.compareTo(b.splitIndex));
      }
      final waypointsBySession = <String, List<CardioWaypoint>>{};
      for (final row in await _db.select(_db.cardioWaypoints).get()) {
        waypointsBySession
            .putIfAbsent(row.sessionClientId, () => [])
            .add(_cardioWaypointFromRow(row));
      }
      for (final waypoints in waypointsBySession.values) {
        waypoints.sort((a, b) => a.waypointIndex.compareTo(b.waypointIndex));
      }

      final sessions = sessionRows
          .map((row) => _toDomain(
                row,
                exercisesBySession[row.clientId] ?? const [],
                setsBySession[row.clientId] ?? const [],
                cardio: cardioBySession[row.clientId],
                splits: splitsBySession[row.clientId] ?? const [],
                waypoints: waypointsBySession[row.clientId] ?? const [],
              ))
          .toList()
        // Upcoming (not-yet-started) sessions have no startedAt — fall back
        // to scheduledFor so the comparator never sees a null.
        ..sort((a, b) {
          final aKey = a.startedAt ?? a.scheduledFor ?? DateTime(0);
          final bKey = b.startedAt ?? b.scheduledFor ?? DateTime(0);
          return bKey.compareTo(aKey);
        });
      return sessions;
    });
  }

  /// Same as [watchAll], narrowed to one [SessionKind] code (`'STRENGTH'` or
  /// `'CARDIO'`) — the fajta-szűrő (docs/cardio/53-cardio-mobile-plan.md §6,
  /// C1.7). `null` means every kind, same as [watchAll] itself; implemented
  /// as a filter over [watchAll] rather than a second Drift query so there is
  /// exactly one place that assembles a session's exercises/sets/cardio.
  Stream<List<WorkoutSession>> watchByKind(String? kind) {
    if (kind == null) return watchAll();
    return watchAll().map((sessions) => sessions.where((s) => s.sessionKind == kind).toList());
  }

  /// Looks up a single session by its backend id — used by the trainer-comment
  /// push tap to open the exact commented session (docs/31-session-feedback-loop-plan.md,
  /// M3). Returns null if it hasn't synced to this device yet (e.g. the push
  /// beat the next pull); the caller falls back to the workouts tab.
  Future<WorkoutSession?> findByServerId(int serverId) async {
    final row = await (_db.select(_db.workoutSessions)
          ..where((t) => t.serverId.equals(serverId)))
        .getSingleOrNull();
    if (row == null) return null;
    return _loadAggregate(row);
  }

  /// The [clientId] counterpart of [findByServerId] — a one-shot read of a
  /// single session with its planned exercises and sets. Used by the
  /// standalone-session processor, which has to see what's already on the row
  /// before it writes the watch's version over it (a watch-mastered session
  /// can also be logged into from the phone, and the watch's payload doesn't
  /// know about those sets).
  Future<WorkoutSession?> findByClientId(String clientId) async {
    final row = await (_db.select(_db.workoutSessions)
          ..where((t) => t.clientId.equals(clientId)))
        .getSingleOrNull();
    if (row == null) return null;
    return _loadAggregate(row);
  }

  Future<WorkoutSession> _loadAggregate(WorkoutSessionRow row) async {
    final exerciseNames = {
      for (final e in await _db.select(_db.exercises).get()) e.clientId: e.name,
    };
    final plannedRows = await (_db.select(_db.workoutSessionExercises)
          ..where((t) => t.sessionClientId.equals(row.clientId)))
        .get();
    final setRows = await (_db.select(_db.exerciseSets)
          ..where((t) => t.sessionClientId.equals(row.clientId)))
        .get();

    final exercises = [
      for (final p in plannedRows)
        SessionExercise(
          exerciseClientId: p.exerciseClientId,
          exerciseName: exerciseNames[p.exerciseClientId] ?? 'Unknown',
          targetSets: p.targetSets,
        ),
    ];
    final sets = [
      for (final s in setRows)
        ExerciseSet(
          exerciseClientId: s.exerciseClientId,
          exerciseName: exerciseNames[s.exerciseClientId] ?? 'Unknown',
          reps: s.reps,
          weight: s.weight,
          performedAt: s.performedAt,
        ),
    ]..sort((a, b) => a.performedAt.compareTo(b.performedAt));

    final cardio = await _loadCardioMetrics(row.clientId);
    final splits = await _loadCardioSplits(row.clientId);
    final waypoints = await _loadCardioWaypoints(row.clientId);

    return _toDomain(row, exercises, sets, cardio: cardio, splits: splits, waypoints: waypoints);
  }

  /// Returns the newly generated [WorkoutSession.clientId] so callers can keep
  /// editing the same session (e.g. auto-saving each set without re-creating).
  ///
  /// [clientId] is normally left null (a fresh one is generated) — the
  /// standalone-session processor is the one caller that passes it
  /// explicitly, using the watch-generated `standaloneSessionId` as the
  /// session's `clientId` itself so a retried delivery is idempotent by
  /// construction (docs/watch/44-watch-f6-standalone-plan.md §4.1, D-F6.3;
  /// call [existsByClientId] first to decide whether to call this at all).
  Future<String> create({
    String? clientId,
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<PlannedExerciseInput> exercises,
    required List<ExerciseSetInput> sets,
    double? activeCalories,
    double? averageHeartRate,
    String? healthWorkoutId,
    String? templateClientId,
    String? templateName,
    int? rpe,
    String? feedbackNote,
    String sessionKind = 'STRENGTH',
    String? activityType,
    int? movingSeconds,
    // Client-only live-session checkpoint (docs/cardio/59-cardio-implementation-plan.md
    // C2.1) — never part of [_payload], see the Drift column doc for why.
    int? movingSinceEpochMs,
    CardioMetrics? cardio,
    List<CardioSplit> splits = const [],
    List<CardioWaypoint> waypoints = const [],
  }) async {
    final resolvedClientId = clientId ?? newClientId();
    await _db.transaction(() async {
      await _db.into(_db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              clientId: resolvedClientId,
              startedAt: Value(startedAt),
              finishedAt: Value(finishedAt),
              activeCalories: Value(activeCalories),
              averageHeartRate: Value(averageHeartRate),
              healthWorkoutId: Value(healthWorkoutId),
              templateClientId: Value(templateClientId),
              templateName: Value(templateName),
              rpe: Value(rpe),
              feedbackNote: Value(feedbackNote),
              sessionKind: Value(sessionKind),
              activityType: Value(activityType),
              movingSeconds: Value(movingSeconds),
              movingSinceEpochMs: Value(movingSinceEpochMs),
            ),
          );
      await _insertChildren(resolvedClientId, exercises, sets);
      await _replaceCardio(resolvedClientId, cardio, splits);
      await _replaceWaypoints(resolvedClientId, waypoints);
    });
    await _outbox.enqueueCreate(
      clientId: resolvedClientId,
      entityType: 'workout_session',
      payload: _payload(
        startedAt: startedAt,
        finishedAt: finishedAt,
        exercises: exercises,
        sets: sets,
        activeCalories: activeCalories,
        averageHeartRate: averageHeartRate,
        healthWorkoutId: healthWorkoutId,
        templateClientId: templateClientId,
        rpe: rpe,
        feedbackNote: feedbackNote,
        sessionKind: sessionKind,
        activityType: activityType,
        movingSeconds: movingSeconds,
        cardio: cardio,
        splits: splits,
        waypoints: waypoints,
      ),
    );
    return resolvedClientId;
  }

  /// Whether a session with this [clientId] already exists locally — the
  /// idempotency check the standalone-session processor runs before calling
  /// [create] (docs/watch/44-watch-f6-standalone-plan.md §4.1, D-F6.2): the
  /// watch retries an un-acked delivery, so the same `standaloneSessionId`
  /// can arrive more than once and must be a no-op (besides the ack) the
  /// second time.
  Future<bool> existsByClientId(String clientId) async {
    final row = await (_db.select(_db.workoutSessions)
          ..where((t) => t.clientId.equals(clientId)))
        .getSingleOrNull();
    return row != null;
  }

  /// Null if no session with this [clientId] exists yet; otherwise whether it
  /// already has a [WorkoutSession.finishedAt] — the three-way check the
  /// standalone-session processor needs to tell "doesn't exist yet (create)"
  /// apart from "exists but still running (was adopted mid-workout, now
  /// needs finishing)" and "exists and already finished (dedup, no-op)"
  /// (docs/watch/44-watch-f6-standalone-plan.md §4.2, extended for live
  /// adoption).
  Future<bool?> isFinishedByClientId(String clientId) async {
    final row = await (_db.select(_db.workoutSessions)
          ..where((t) => t.clientId.equals(clientId)))
        .getSingleOrNull();
    if (row == null) return null;
    return row.finishedAt != null;
  }

  /// The enrichment fields ([activeCalories], [averageHeartRate],
  /// [healthWorkoutId], [rpe], [feedbackNote]) use [Value] so "not my field"
  /// and "clear this field" stay distinct: an absent field keeps whatever the
  /// row currently holds. Callers pass only the fields their flow owns — the
  /// health import doesn't know about the rating, the session editor doesn't
  /// know about health data — and both the server payload and the backend's
  /// update are full replaces, so a caller-supplied null would otherwise wipe
  /// the other flow's data (rating a session used to disconnect its Apple
  /// Health workout, and vice versa).
  /// [sessionKind]/[activityType]/[movingSeconds]/[cardio]/[splits] follow
  /// the same absent-preserving [Value] convention as the health/rating
  /// fields above, for the same reason: `rate()` and [enrichHealthMetrics]
  /// call through here without knowing anything about cardio, and must not
  /// wipe a cardio session's data just by rating it or pairing its Apple
  /// Health workout. Only the session editor (the one flow that actually
  /// owns this data) passes them explicitly.
  ///
  /// A present-but-null [cardio] genuinely clears the session's cardio row
  /// (full-replace, matching [exercises]/[sets]) — the editor always sends
  /// its complete current cardio state, never "no opinion" via null (that's
  /// what leaving the parameter absent is for).
  Future<void> update(
    String clientId, {
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<PlannedExerciseInput> exercises,
    required List<ExerciseSetInput> sets,
    Value<double?> activeCalories = const Value.absent(),
    Value<double?> averageHeartRate = const Value.absent(),
    Value<String?> healthWorkoutId = const Value.absent(),
    Value<int?> rpe = const Value.absent(),
    Value<String?> feedbackNote = const Value.absent(),
    Value<String> sessionKind = const Value.absent(),
    Value<String?> activityType = const Value.absent(),
    Value<int?> movingSeconds = const Value.absent(),
    // Client-only live-session checkpoint, same absent-preserving convention
    // as the rest — never part of [_payload] (docs/cardio/
    // 59-cardio-implementation-plan.md C2.1).
    Value<int?> movingSinceEpochMs = const Value.absent(),
    Value<CardioMetrics?> cardio = const Value.absent(),
    Value<List<CardioSplit>> splits = const Value.absent(),
    Value<List<CardioWaypoint>> waypoints = const Value.absent(),
  }) async {
    // Merged (caller-supplied or preserved) values, resolved inside the
    // transaction but also needed for the outbox payload below.
    double? mergedActiveCalories;
    double? mergedAverageHeartRate;
    String? mergedHealthWorkoutId;
    int? mergedRpe;
    String? mergedFeedbackNote;
    String mergedSessionKind = 'STRENGTH';
    String? mergedActivityType;
    int? mergedMovingSeconds;
    int? mergedMovingSinceEpochMs;
    CardioMetrics? mergedCardio;
    List<CardioSplit> mergedSplits = const [];
    List<CardioWaypoint> mergedWaypoints = const [];
    await _db.transaction(() async {
      final row = await (_db.select(_db.workoutSessions)
            ..where((t) => t.clientId.equals(clientId)))
          .getSingle();
      mergedActiveCalories =
          activeCalories.present ? activeCalories.value : row.activeCalories;
      mergedAverageHeartRate = averageHeartRate.present
          ? averageHeartRate.value
          : row.averageHeartRate;
      mergedHealthWorkoutId =
          healthWorkoutId.present ? healthWorkoutId.value : row.healthWorkoutId;
      mergedRpe = rpe.present ? rpe.value : row.rpe;
      mergedFeedbackNote =
          feedbackNote.present ? feedbackNote.value : row.feedbackNote;
      mergedSessionKind = sessionKind.present ? sessionKind.value : row.sessionKind;
      mergedActivityType = activityType.present ? activityType.value : row.activityType;
      mergedMovingSeconds =
          movingSeconds.present ? movingSeconds.value : row.movingSeconds;
      mergedMovingSinceEpochMs = movingSinceEpochMs.present
          ? movingSinceEpochMs.value
          : row.movingSinceEpochMs;
      mergedCardio = cardio.present ? cardio.value : await _loadCardioMetrics(clientId);
      mergedSplits = splits.present ? splits.value : await _loadCardioSplits(clientId);
      mergedWaypoints =
          waypoints.present ? waypoints.value : await _loadCardioWaypoints(clientId);
      await (_db.update(_db.workoutSessions)
            ..where((t) => t.clientId.equals(clientId)))
          .write(
        WorkoutSessionsCompanion(
          startedAt: Value(startedAt),
          finishedAt: Value(finishedAt),
          activeCalories: Value(mergedActiveCalories),
          averageHeartRate: Value(mergedAverageHeartRate),
          healthWorkoutId: Value(mergedHealthWorkoutId),
          rpe: Value(mergedRpe),
          feedbackNote: Value(mergedFeedbackNote),
          sessionKind: Value(mergedSessionKind),
          activityType: Value(mergedActivityType),
          movingSeconds: Value(mergedMovingSeconds),
          movingSinceEpochMs: Value(mergedMovingSinceEpochMs),
        ),
      );
      await (_db.delete(_db.workoutSessionExercises)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      await (_db.delete(_db.exerciseSets)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      await _insertChildren(clientId, exercises, sets);
      await _replaceCardio(clientId, mergedCardio, mergedSplits);
      await _replaceWaypoints(clientId, mergedWaypoints);
    });
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'workout_session',
      payload: _payload(
        startedAt: startedAt,
        finishedAt: finishedAt,
        exercises: exercises,
        sets: sets,
        activeCalories: mergedActiveCalories,
        averageHeartRate: mergedAverageHeartRate,
        healthWorkoutId: mergedHealthWorkoutId,
        rpe: mergedRpe,
        feedbackNote: mergedFeedbackNote,
        sessionKind: mergedSessionKind,
        activityType: mergedActivityType,
        movingSeconds: mergedMovingSeconds,
        cardio: mergedCardio,
        splits: mergedSplits,
        waypoints: mergedWaypoints,
      ),
    );
  }

  /// Rates a finished session's difficulty without the caller needing its
  /// full editing state in memory (e.g. the dashboard's "rate this workout"
  /// nudge) — reads the session's current fields/children and resubmits them
  /// through [update] with the new rating, since sessions are always synced
  /// as a full replace. The other enrichment fields are left absent so
  /// [update] preserves them from the row.
  Future<void> rate(
    String clientId, {
    required int rpe,
    String? feedbackNote,
  }) async {
    final row = await (_db.select(_db.workoutSessions)
          ..where((t) => t.clientId.equals(clientId)))
        .getSingle();
    final plannedRows = await (_db.select(_db.workoutSessionExercises)
          ..where((t) => t.sessionClientId.equals(clientId)))
        .get();
    final setRows = await (_db.select(_db.exerciseSets)
          ..where((t) => t.sessionClientId.equals(clientId)))
        .get();

    await update(
      clientId,
      startedAt: row.startedAt!,
      finishedAt: row.finishedAt,
      exercises: [
        for (final p in plannedRows)
          PlannedExerciseInput(
              exerciseClientId: p.exerciseClientId, targetSets: p.targetSets),
      ],
      sets: [
        for (final s in setRows)
          ExerciseSetInput(
            exerciseClientId: s.exerciseClientId,
            reps: s.reps,
            weight: s.weight,
            performedAt: s.performedAt,
          ),
      ],
      rpe: Value(rpe),
      feedbackNote: Value(feedbackNote),
    );
  }

  /// Enriches a session with health-adjacent metrics without the caller
  /// holding its full editing state in memory — mirrors [rate]'s
  /// read-then-resubmit pattern. Backs the watch-workout summary handler
  /// (docs/40-watch-app-plan.md §6.3), which only has {clientId,
  /// activeCalories, averageHeartRate, healthWorkoutId} on hand and may run
  /// at cold start, long after the session's editing screen is gone. rpe/
  /// feedbackNote are left absent so this can't disturb a rating.
  Future<void> enrichHealthMetrics(
    String clientId, {
    Value<double?> activeCalories = const Value.absent(),
    Value<double?> averageHeartRate = const Value.absent(),
    Value<String?> healthWorkoutId = const Value.absent(),
    // docs/cardio/55-cardio-watch-plan.md §4.3, C5.7a — the caller (`WorkoutResumePrompt`)
    // already merged this with the session's own existing `cardio` via
    // `CardioMetrics.mergedWithWatchMeasurement`, so passing it straight
    // through to `update()`'s wholesale-replace `cardio` param is correct
    // here, unlike re-reading `plannedRows`/`setRows` below (which this
    // method owns re-fetching itself, since those never need merging against
    // watch data).
    Value<CardioMetrics?> cardio = const Value.absent(),
  }) async {
    final row = await (_db.select(_db.workoutSessions)
          ..where((t) => t.clientId.equals(clientId)))
        .getSingle();
    final plannedRows = await (_db.select(_db.workoutSessionExercises)
          ..where((t) => t.sessionClientId.equals(clientId)))
        .get();
    final setRows = await (_db.select(_db.exerciseSets)
          ..where((t) => t.sessionClientId.equals(clientId)))
        .get();

    await update(
      clientId,
      startedAt: row.startedAt!,
      finishedAt: row.finishedAt,
      exercises: [
        for (final p in plannedRows)
          PlannedExerciseInput(
              exerciseClientId: p.exerciseClientId, targetSets: p.targetSets),
      ],
      sets: [
        for (final s in setRows)
          ExerciseSetInput(
            exerciseClientId: s.exerciseClientId,
            reps: s.reps,
            weight: s.weight,
            performedAt: s.performedAt,
          ),
      ],
      activeCalories: activeCalories,
      averageHeartRate: averageHeartRate,
      healthWorkoutId: healthWorkoutId,
      cardio: cardio,
    );
  }

  Future<void> delete(String clientId) async {
    // Must enqueue before the local row is gone — enqueueDelete needs to
    // read its serverId while the row still exists. If it queued a server
    // delete, the session and its exercise links/sets stay (hidden by the
    // controller's filter) until that delete is confirmed — see
    // EntitySyncConfig.cleanupChildren's doc.
    final queued = await _outbox.enqueueDelete(
        clientId: clientId, entityType: 'workout_session');
    if (!queued) {
      await _db.transaction(() async {
        await (_db.delete(_db.workoutSessionExercises)
              ..where((t) => t.sessionClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.exerciseSets)
              ..where((t) => t.sessionClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.cardioDetails)
              ..where((t) => t.sessionClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.cardioSplits)
              ..where((t) => t.sessionClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.cardioWaypoints)
              ..where((t) => t.sessionClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.cardioTrackPoints)
              ..where((t) => t.sessionClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.workoutSessions)
              ..where((t) => t.clientId.equals(clientId)))
            .go();
      });
    }
  }

  Future<void> _insertChildren(
    String sessionClientId,
    List<PlannedExerciseInput> exercises,
    List<ExerciseSetInput> sets,
  ) async {
    for (final exercise in exercises) {
      await _db.into(_db.workoutSessionExercises).insert(
            WorkoutSessionExercisesCompanion.insert(
              clientId: newClientId(),
              sessionClientId: sessionClientId,
              exerciseClientId: exercise.exerciseClientId,
              targetSets: Value(exercise.targetSets),
            ),
          );
    }
    for (final set in sets) {
      await _db.into(_db.exerciseSets).insert(
            ExerciseSetsCompanion.insert(
              clientId: newClientId(),
              sessionClientId: sessionClientId,
              exerciseClientId: set.exerciseClientId,
              reps: set.reps,
              weight: set.weight,
              performedAt: set.performedAt,
            ),
          );
    }
  }

  /// Rebuilds a session's cardio-metrics row and split list from scratch —
  /// the same full-replace model as [_insertChildren], and (like it) always
  /// called from inside the caller's transaction. A null [cardio] simply
  /// leaves no row, same as a session that never had cardio data.
  Future<void> _replaceCardio(
    String sessionClientId,
    CardioMetrics? cardio,
    List<CardioSplit> splits,
  ) async {
    await (_db.delete(_db.cardioDetails)
          ..where((t) => t.sessionClientId.equals(sessionClientId)))
        .go();
    if (cardio != null) {
      await _db.into(_db.cardioDetails).insert(
            CardioDetailsCompanion.insert(
              sessionClientId: sessionClientId,
              distanceMeters: Value(cardio.distanceMeters),
              elevationGainMeters: Value(cardio.elevationGainMeters),
              elevationLossMeters: Value(cardio.elevationLossMeters),
              maxAltitudeMeters: Value(cardio.maxAltitudeMeters),
              steps: Value(cardio.steps),
              avgCadence: Value(cardio.avgCadence),
              maxCadence: Value(cardio.maxCadence),
              best1kSeconds: Value(cardio.best1kSeconds),
              best5kSeconds: Value(cardio.best5kSeconds),
              best10kSeconds: Value(cardio.best10kSeconds),
              avgWatts: Value(cardio.avgWatts),
              maxWatts: Value(cardio.maxWatts),
              resistanceLevel: Value(cardio.resistanceLevel),
              deviceCalories: Value(cardio.deviceCalories),
              maxHeartRate: Value(cardio.maxHeartRate),
              hrZone1Seconds: Value(cardio.hrZone1Seconds),
              hrZone2Seconds: Value(cardio.hrZone2Seconds),
              hrZone3Seconds: Value(cardio.hrZone3Seconds),
              hrZone4Seconds: Value(cardio.hrZone4Seconds),
              hrZone5Seconds: Value(cardio.hrZone5Seconds),
              intensity: Value(cardio.intensity),
              venue: Value(cardio.venue),
              gameFormat: Value(cardio.gameFormat),
              scorePoints: Value(cardio.scorePoints),
              scoreAssists: Value(cardio.scoreAssists),
              scoreRebounds: Value(cardio.scoreRebounds),
              distanceSource: Value(cardio.distanceSource),
              caloriesSource: Value(cardio.caloriesSource),
              routePolyline: Value(cardio.routePolyline),
              routePointCount: Value(cardio.routePointCount),
              backpackWeightKg: Value(cardio.backpackWeightKg),
              weatherCondition: Value(cardio.weatherCondition),
              weatherTempC: Value(cardio.weatherTempC),
              weatherWindKph: Value(cardio.weatherWindKph),
              weatherPrecipMm: Value(cardio.weatherPrecipMm),
              avgGapSecondsPerKm: Value(cardio.avgGapSecondsPerKm),
            ),
          );
    }

    await (_db.delete(_db.cardioSplits)
          ..where((t) => t.sessionClientId.equals(sessionClientId)))
        .go();
    for (final split in splits) {
      await _db.into(_db.cardioSplits).insert(
            CardioSplitsCompanion.insert(
              clientId: newClientId(),
              sessionClientId: sessionClientId,
              splitIndex: split.splitIndex,
              splitType: Value(split.splitType.wire),
              distanceMeters: Value(split.distanceMeters),
              durationSeconds: split.durationSeconds,
              elevationDeltaM: Value(split.elevationDeltaM),
              avgHeartRate: Value(split.avgHeartRate),
              avgWatts: Value(split.avgWatts),
              intensity: Value(split.intensity?.wire),
            ),
          );
    }
  }

  /// [_replaceCardio]'s counterpart for a session's waypoint list — its own
  /// method rather than folded into [_replaceCardio] since a waypoint can be
  /// marked mid-session (docs/cardio/60 C8.4) without touching `cardio` at
  /// all, and the two full-replace independently either way.
  Future<void> _replaceWaypoints(
    String sessionClientId,
    List<CardioWaypoint> waypoints,
  ) async {
    await (_db.delete(_db.cardioWaypoints)
          ..where((t) => t.sessionClientId.equals(sessionClientId)))
        .go();
    for (final waypoint in waypoints) {
      await _db.into(_db.cardioWaypoints).insert(
            CardioWaypointsCompanion.insert(
              clientId: newClientId(),
              sessionClientId: sessionClientId,
              waypointIndex: waypoint.waypointIndex,
              latitude: waypoint.latitude,
              longitude: waypoint.longitude,
              altitudeMeters: Value(waypoint.altitudeMeters),
              label: Value(waypoint.label),
            ),
          );
    }
  }

  /// The [update]-merge counterpart of [_replaceCardio]'s write side — reads
  /// what's currently stored, for a caller (e.g. [rate]) that didn't pass a
  /// [Value] for `cardio` and therefore isn't asking to change it.
  Future<CardioMetrics?> _loadCardioMetrics(String sessionClientId) async {
    final row = await (_db.select(_db.cardioDetails)
          ..where((t) => t.sessionClientId.equals(sessionClientId)))
        .getSingleOrNull();
    return row == null ? null : _cardioMetricsFromRow(row);
  }

  Future<List<CardioSplit>> _loadCardioSplits(String sessionClientId) async {
    final rows = await (_db.select(_db.cardioSplits)
          ..where((t) => t.sessionClientId.equals(sessionClientId))
          ..orderBy([(t) => OrderingTerm.asc(t.splitIndex)]))
        .get();
    return [for (final row in rows) _cardioSplitFromRow(row)];
  }

  Future<List<CardioWaypoint>> _loadCardioWaypoints(String sessionClientId) async {
    final rows = await (_db.select(_db.cardioWaypoints)
          ..where((t) => t.sessionClientId.equals(sessionClientId))
          ..orderBy([(t) => OrderingTerm.asc(t.waypointIndex)]))
        .get();
    return [for (final row in rows) _cardioWaypointFromRow(row)];
  }

  CardioMetrics _cardioMetricsFromRow(CardioDetailsRow row) {
    return CardioMetrics(
      distanceMeters: row.distanceMeters,
      elevationGainMeters: row.elevationGainMeters,
      elevationLossMeters: row.elevationLossMeters,
      maxAltitudeMeters: row.maxAltitudeMeters,
      steps: row.steps,
      avgCadence: row.avgCadence,
      maxCadence: row.maxCadence,
      best1kSeconds: row.best1kSeconds,
      best5kSeconds: row.best5kSeconds,
      best10kSeconds: row.best10kSeconds,
      avgWatts: row.avgWatts,
      maxWatts: row.maxWatts,
      resistanceLevel: row.resistanceLevel,
      deviceCalories: row.deviceCalories,
      maxHeartRate: row.maxHeartRate,
      hrZone1Seconds: row.hrZone1Seconds,
      hrZone2Seconds: row.hrZone2Seconds,
      hrZone3Seconds: row.hrZone3Seconds,
      hrZone4Seconds: row.hrZone4Seconds,
      hrZone5Seconds: row.hrZone5Seconds,
      intensity: row.intensity,
      venue: row.venue,
      gameFormat: row.gameFormat,
      scorePoints: row.scorePoints,
      scoreAssists: row.scoreAssists,
      scoreRebounds: row.scoreRebounds,
      distanceSource: row.distanceSource,
      caloriesSource: row.caloriesSource,
      routePolyline: row.routePolyline,
      routePointCount: row.routePointCount,
      backpackWeightKg: row.backpackWeightKg,
      weatherCondition: row.weatherCondition,
      weatherTempC: row.weatherTempC,
      weatherWindKph: row.weatherWindKph,
      weatherPrecipMm: row.weatherPrecipMm,
      avgGapSecondsPerKm: row.avgGapSecondsPerKm,
    );
  }

  CardioSplit _cardioSplitFromRow(CardioSplitRow row) {
    return CardioSplit(
      splitIndex: row.splitIndex,
      splitType: CardioSplitType.fromWire(row.splitType),
      distanceMeters: row.distanceMeters,
      durationSeconds: row.durationSeconds,
      elevationDeltaM: row.elevationDeltaM,
      avgHeartRate: row.avgHeartRate,
      avgWatts: row.avgWatts,
      intensity: row.intensity == null ? null : IntervalIntensity.fromWire(row.intensity!),
    );
  }

  CardioWaypoint _cardioWaypointFromRow(CardioWaypointRow row) {
    return CardioWaypoint(
      waypointIndex: row.waypointIndex,
      latitude: row.latitude,
      longitude: row.longitude,
      altitudeMeters: row.altitudeMeters,
      label: row.label,
    );
  }

  Map<String, dynamic> _payload({
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<PlannedExerciseInput> exercises,
    required List<ExerciseSetInput> sets,
    double? activeCalories,
    double? averageHeartRate,
    String? healthWorkoutId,
    String? templateClientId,
    int? rpe,
    String? feedbackNote,
    String sessionKind = 'STRENGTH',
    String? activityType,
    int? movingSeconds,
    CardioMetrics? cardio,
    List<CardioSplit> splits = const [],
    List<CardioWaypoint> waypoints = const [],
  }) {
    return {
      'startedAt': startedAt.toUtc().toIso8601String(),
      if (finishedAt != null)
        'finishedAt': finishedAt.toUtc().toIso8601String(),
      'exerciseIds':
          exercises.map((e) => clientRef(e.exerciseClientId)).toList(),
      // The same planned exercises, but carrying each one's targetSets — how
      // many set rows the session plans for it. Sent *alongside* the bare
      // `exerciseIds` above rather than replacing it: the field is additive on
      // the backend (which still requires exerciseIds, and which older server
      // builds don't know about at all), so sending both is what keeps this
      // payload valid against either. Without it, targetSets never left the
      // device and every pull brought the session back with its
      // planned-but-not-yet-logged rows gone.
      'plannedExercises': [
        for (final e in exercises)
          {
            'exerciseId': clientRef(e.exerciseClientId),
            if (e.targetSets != null) 'targetSets': e.targetSets,
          },
      ],
      'sets': sets
          .map((s) => {
                'exerciseId': clientRef(s.exerciseClientId),
                'reps': s.reps,
                'weight': s.weight,
                'performedAt': s.performedAt.toUtc().toIso8601String(),
              })
          .toList(),
      if (activeCalories != null) 'activeCalories': activeCalories,
      if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
      if (healthWorkoutId != null) 'healthWorkoutId': healthWorkoutId,
      if (templateClientId != null) 'templateId': clientRef(templateClientId),
      if (rpe != null) 'rpe': rpe,
      if (feedbackNote != null) 'feedbackNote': feedbackNote,
      // Omitted entirely for a STRENGTH session (the default) — a client
      // that predates cardio never sent these keys, and this payload must
      // stay byte-identical for it (docs/cardio/59-cardio-implementation-plan.md
      // C1.5's regression requirement).
      if (sessionKind != 'STRENGTH') 'sessionKind': sessionKind,
      if (activityType != null) 'activityType': activityType,
      if (movingSeconds != null) 'movingSeconds': movingSeconds,
      if (cardio != null) 'cardio': _cardioPayload(cardio),
      if (splits.isNotEmpty)
        'splits': splits.map(_splitPayload).toList(),
      if (waypoints.isNotEmpty)
        'waypoints': waypoints.map(_waypointPayload).toList(),
    };
  }

  /// Field order mirrors the backend's `CardioDetailsRequest` exactly
  /// (docs/cardio/52-cardio-domain-backend-plan.md §3.2). Nulls are sent
  /// explicitly rather than omitted — simpler than 27 individual `if`s, and
  /// Jackson binds a JSON `null` to a nullable record component the same way
  /// it binds an absent key.
  Map<String, dynamic> _cardioPayload(CardioMetrics cardio) {
    return {
      'distanceMeters': cardio.distanceMeters,
      'elevationGainMeters': cardio.elevationGainMeters,
      'elevationLossMeters': cardio.elevationLossMeters,
      'maxAltitudeMeters': cardio.maxAltitudeMeters,
      'steps': cardio.steps,
      'avgCadence': cardio.avgCadence,
      'maxCadence': cardio.maxCadence,
      'best1kSeconds': cardio.best1kSeconds,
      'best5kSeconds': cardio.best5kSeconds,
      'best10kSeconds': cardio.best10kSeconds,
      'avgWatts': cardio.avgWatts,
      'maxWatts': cardio.maxWatts,
      'resistanceLevel': cardio.resistanceLevel,
      'deviceCalories': cardio.deviceCalories,
      'maxHeartRate': cardio.maxHeartRate,
      'hrZone1Seconds': cardio.hrZone1Seconds,
      'hrZone2Seconds': cardio.hrZone2Seconds,
      'hrZone3Seconds': cardio.hrZone3Seconds,
      'hrZone4Seconds': cardio.hrZone4Seconds,
      'hrZone5Seconds': cardio.hrZone5Seconds,
      'intensity': cardio.intensity,
      'venue': cardio.venue,
      'gameFormat': cardio.gameFormat,
      'scorePoints': cardio.scorePoints,
      'scoreAssists': cardio.scoreAssists,
      'scoreRebounds': cardio.scoreRebounds,
      'distanceSource': cardio.distanceSource,
      'caloriesSource': cardio.caloriesSource,
      'routePolyline': cardio.routePolyline,
      'routePointCount': cardio.routePointCount,
      'backpackWeightKg': cardio.backpackWeightKg,
      'weatherCondition': cardio.weatherCondition,
      'weatherTempC': cardio.weatherTempC,
      'weatherWindKph': cardio.weatherWindKph,
      'weatherPrecipMm': cardio.weatherPrecipMm,
      'avgGapSecondsPerKm': cardio.avgGapSecondsPerKm,
    };
  }

  /// Field order mirrors the backend's `CardioSplitRequest`
  /// (docs/cardio/60 C7.1). `splitType` is sent explicitly rather than left
  /// to the server's default: an INTERVAL section without it would be
  /// rejected for having no distance.
  Map<String, dynamic> _splitPayload(CardioSplit split) {
    return {
      'splitIndex': split.splitIndex,
      'splitType': split.splitType.wire,
      'distanceMeters': split.distanceMeters,
      'durationSeconds': split.durationSeconds,
      'elevationDeltaM': split.elevationDeltaM,
      'avgHeartRate': split.avgHeartRate,
      'avgWatts': split.avgWatts,
      'intensity': split.intensity?.wire,
    };
  }

  /// Field order mirrors the backend's `CardioWaypointRequest`
  /// (docs/cardio/60 C8.1/C8.4).
  Map<String, dynamic> _waypointPayload(CardioWaypoint waypoint) {
    return {
      'waypointIndex': waypoint.waypointIndex,
      'latitude': waypoint.latitude,
      'longitude': waypoint.longitude,
      'altitudeMeters': waypoint.altitudeMeters,
      'label': waypoint.label,
    };
  }

  WorkoutSession _toDomain(
    WorkoutSessionRow row,
    List<SessionExercise> exercises,
    List<ExerciseSet> sets, {
    CardioMetrics? cardio,
    List<CardioSplit> splits = const [],
    List<CardioWaypoint> waypoints = const [],
  }) {
    return WorkoutSession(
      clientId: row.clientId,
      id: row.serverId,
      startedAt: row.startedAt,
      finishedAt: row.finishedAt,
      exercises: exercises,
      sets: sets,
      activeCalories: row.activeCalories,
      averageHeartRate: row.averageHeartRate,
      healthWorkoutId: row.healthWorkoutId,
      templateClientId: row.templateClientId,
      templateName: row.templateName,
      scheduledFor: row.scheduledFor,
      scheduledTime: row.scheduledTime,
      scheduleId: row.scheduleId,
      rpe: row.rpe,
      feedbackNote: row.feedbackNote,
      trainerComment: row.trainerComment,
      trainerCommentAt: row.trainerCommentAt,
      sessionKind: row.sessionKind,
      activityType: row.activityType,
      movingSeconds: row.movingSeconds,
      movingSinceEpochMs: row.movingSinceEpochMs,
      cardio: cardio,
      splits: splits,
      waypoints: waypoints,
    );
  }

  /// Finds the most recent *other* session that logged sets for
  /// [exerciseClientId], preferring one started from the same
  /// [templateClientId] if given. Falls back to the most recent session with
  /// this exercise regardless of template when the template-scoped search
  /// comes up empty (or no template was given). Returns the matching
  /// session's sets for this exercise, sorted by weight descending so callers
  /// can pair them positionally with the current session's rows.
  Future<List<PreviousSetHint>> getPreviousPerformance({
    required String exerciseClientId,
    String? templateClientId,
    String? excludeSessionClientId,
  }) async {
    if (templateClientId != null) {
      final scoped = await _lastSessionSets(
        exerciseClientId: exerciseClientId,
        excludeSessionClientId: excludeSessionClientId,
        templateClientId: templateClientId,
      );
      if (scoped.isNotEmpty) return scoped;
    }
    return _lastSessionSets(
      exerciseClientId: exerciseClientId,
      excludeSessionClientId: excludeSessionClientId,
    );
  }

  /// Builds a [PrBaseline] for [exerciseClientId] from every set ever logged
  /// for it, excluding [excludeSessionClientId] (the session currently being
  /// edited, if any — its own sets must not count as a baseline against
  /// themselves). Template-agnostic by design: unlike
  /// [getPreviousPerformance], a record is a record regardless of which
  /// template (or no template) it was logged under
  /// (docs/38-personal-records-plan.md, M2).
  Future<PrBaseline> getPrBaseline({
    required String exerciseClientId,
    String? excludeSessionClientId,
  }) async {
    final query = _db.select(_db.exerciseSets).join([
      innerJoin(
        _db.workoutSessions,
        _db.workoutSessions.clientId
            .equalsExp(_db.exerciseSets.sessionClientId),
      ),
    ])
      ..where(_db.exerciseSets.exerciseClientId.equals(exerciseClientId));
    if (excludeSessionClientId != null) {
      query.where(
          _db.workoutSessions.clientId.equals(excludeSessionClientId).not());
    }

    final rows = await query.get();
    final sets = [
      for (final r in rows)
        (
          weight: r.readTable(_db.exerciseSets).weight,
          reps: r.readTable(_db.exerciseSets).reps,
          performedAt: r.readTable(_db.exerciseSets).performedAt,
        ),
    ];
    return PrBaseline.fromSets(sets);
  }

  Future<List<PreviousSetHint>> _lastSessionSets({
    required String exerciseClientId,
    String? excludeSessionClientId,
    String? templateClientId,
  }) async {
    final query = _db.select(_db.exerciseSets).join([
      innerJoin(
        _db.workoutSessions,
        _db.workoutSessions.clientId
            .equalsExp(_db.exerciseSets.sessionClientId),
      ),
    ])
      ..where(_db.exerciseSets.exerciseClientId.equals(exerciseClientId))
      ..orderBy([OrderingTerm.desc(_db.workoutSessions.startedAt)]);
    if (excludeSessionClientId != null) {
      query.where(
          _db.workoutSessions.clientId.equals(excludeSessionClientId).not());
    }
    if (templateClientId != null) {
      query
          .where(_db.workoutSessions.templateClientId.equals(templateClientId));
    }

    final rows = await query.get();
    if (rows.isEmpty) return const [];

    final latestSessionId = rows.first.readTable(_db.workoutSessions).clientId;
    final sets = rows
        .map((r) => r.readTable(_db.exerciseSets))
        .where((s) => s.sessionClientId == latestSessionId)
        .toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));

    return [
      for (final s in sets) PreviousSetHint(weight: s.weight, reps: s.reps)
    ];
  }
}

final workoutSessionRepositoryProvider =
    Provider<WorkoutSessionRepository>((ref) {
  return WorkoutSessionRepository(
      ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});

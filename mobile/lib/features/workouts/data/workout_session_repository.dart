import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
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

      final sessions = sessionRows
          .map((row) => _toDomain(
                row,
                exercisesBySession[row.clientId] ?? const [],
                setsBySession[row.clientId] ?? const [],
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

  /// Looks up a single session by its backend id — used by the trainer-comment
  /// push tap to open the exact commented session (docs/31-session-feedback-loop-plan.md,
  /// M3). Returns null if it hasn't synced to this device yet (e.g. the push
  /// beat the next pull); the caller falls back to the workouts tab.
  Future<WorkoutSession?> findByServerId(int serverId) async {
    final row = await (_db.select(_db.workoutSessions)
          ..where((t) => t.serverId.equals(serverId)))
        .getSingleOrNull();
    if (row == null) return null;

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

    return _toDomain(row, exercises, sets);
  }

  /// Returns the newly generated [WorkoutSession.clientId] so callers can keep
  /// editing the same session (e.g. auto-saving each set without re-creating).
  Future<String> create({
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
  }) async {
    final clientId = newClientId();
    await _db.transaction(() async {
      await _db.into(_db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              clientId: clientId,
              startedAt: Value(startedAt),
              finishedAt: Value(finishedAt),
              activeCalories: Value(activeCalories),
              averageHeartRate: Value(averageHeartRate),
              healthWorkoutId: Value(healthWorkoutId),
              templateClientId: Value(templateClientId),
              templateName: Value(templateName),
              rpe: Value(rpe),
              feedbackNote: Value(feedbackNote),
            ),
          );
      await _insertChildren(clientId, exercises, sets);
    });
    await _outbox.enqueueCreate(
      clientId: clientId,
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
      ),
    );
    return clientId;
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
  }) async {
    // Merged (caller-supplied or preserved) values, resolved inside the
    // transaction but also needed for the outbox payload below.
    double? mergedActiveCalories;
    double? mergedAverageHeartRate;
    String? mergedHealthWorkoutId;
    int? mergedRpe;
    String? mergedFeedbackNote;
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
        ),
      );
      await (_db.delete(_db.workoutSessionExercises)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      await (_db.delete(_db.exerciseSets)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      await _insertChildren(clientId, exercises, sets);
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
  }) {
    return {
      'startedAt': startedAt.toUtc().toIso8601String(),
      if (finishedAt != null)
        'finishedAt': finishedAt.toUtc().toIso8601String(),
      'exerciseIds':
          exercises.map((e) => clientRef(e.exerciseClientId)).toList(),
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
    };
  }

  WorkoutSession _toDomain(
    WorkoutSessionRow row,
    List<SessionExercise> exercises,
    List<ExerciseSet> sets,
  ) {
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

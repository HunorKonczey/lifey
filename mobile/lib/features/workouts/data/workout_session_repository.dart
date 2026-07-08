import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
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
      ),
    );
    return clientId;
  }

  Future<void> update(
    String clientId, {
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<PlannedExerciseInput> exercises,
    required List<ExerciseSetInput> sets,
    double? activeCalories,
    double? averageHeartRate,
    String? healthWorkoutId,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.workoutSessions)
            ..where((t) => t.clientId.equals(clientId)))
          .write(
        WorkoutSessionsCompanion(
          startedAt: Value(startedAt),
          finishedAt: Value(finishedAt),
          activeCalories: Value(activeCalories),
          averageHeartRate: Value(averageHeartRate),
          healthWorkoutId: Value(healthWorkoutId),
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
        activeCalories: activeCalories,
        averageHeartRate: averageHeartRate,
        healthWorkoutId: healthWorkoutId,
      ),
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

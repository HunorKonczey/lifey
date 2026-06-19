import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
import '../domain/workout_session.dart';

/// One set to record when logging a session (request side).
class ExerciseSetInput {
  const ExerciseSetInput({
    required this.exerciseClientId,
    required this.reps,
    required this.weight,
  });

  final String exerciseClientId;
  final int reps;
  final double weight;
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
    return _db.select(_db.workoutSessions).watch().asyncMap((sessionRows) async {
      if (sessionRows.isEmpty) return const <WorkoutSession>[];

      final exerciseNames = {
        for (final row in await _db.select(_db.exercises).get()) row.clientId: row.name,
      };

      final exercisesBySession = <String, List<SessionExercise>>{};
      for (final link in await _db.select(_db.workoutSessionExercises).get()) {
        exercisesBySession.putIfAbsent(link.sessionClientId, () => []).add(
              SessionExercise(
                exerciseClientId: link.exerciseClientId,
                exerciseName: exerciseNames[link.exerciseClientId] ?? 'Unknown',
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
              ),
            );
      }

      final sessions = sessionRows
          .map((row) => _toDomain(
                row,
                exercisesBySession[row.clientId] ?? const [],
                setsBySession[row.clientId] ?? const [],
              ))
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return sessions;
    });
  }

  Future<void> create({
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<String> exerciseClientIds,
    required List<ExerciseSetInput> sets,
  }) async {
    final clientId = newClientId();
    await _db.transaction(() async {
      await _db.into(_db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              clientId: clientId,
              startedAt: startedAt,
              finishedAt: Value(finishedAt),
            ),
          );
      await _insertChildren(clientId, exerciseClientIds, sets);
    });
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'workout_session',
      payload: _payload(
        startedAt: startedAt,
        finishedAt: finishedAt,
        exerciseClientIds: exerciseClientIds,
        sets: sets,
      ),
    );
  }

  Future<void> update(
    String clientId, {
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<String> exerciseClientIds,
    required List<ExerciseSetInput> sets,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.workoutSessions)..where((t) => t.clientId.equals(clientId))).write(
        WorkoutSessionsCompanion(
          startedAt: Value(startedAt),
          finishedAt: Value(finishedAt),
        ),
      );
      await (_db.delete(_db.workoutSessionExercises)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      await (_db.delete(_db.exerciseSets)..where((t) => t.sessionClientId.equals(clientId))).go();
      await _insertChildren(clientId, exerciseClientIds, sets);
    });
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'workout_session',
      payload: _payload(
        startedAt: startedAt,
        finishedAt: finishedAt,
        exerciseClientIds: exerciseClientIds,
        sets: sets,
      ),
    );
  }

  Future<void> delete(String clientId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.workoutSessionExercises)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .go();
      await (_db.delete(_db.exerciseSets)..where((t) => t.sessionClientId.equals(clientId))).go();
      await (_db.delete(_db.workoutSessions)..where((t) => t.clientId.equals(clientId))).go();
    });
    await _outbox.enqueueDelete(clientId: clientId, entityType: 'workout_session');
  }

  Future<void> _insertChildren(
    String sessionClientId,
    List<String> exerciseClientIds,
    List<ExerciseSetInput> sets,
  ) async {
    for (final exerciseClientId in exerciseClientIds) {
      await _db.into(_db.workoutSessionExercises).insert(
            WorkoutSessionExercisesCompanion.insert(
              clientId: newClientId(),
              sessionClientId: sessionClientId,
              exerciseClientId: exerciseClientId,
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
            ),
          );
    }
  }

  Map<String, dynamic> _payload({
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<String> exerciseClientIds,
    required List<ExerciseSetInput> sets,
  }) {
    return {
      'startedAt': startedAt.toUtc().toIso8601String(),
      if (finishedAt != null) 'finishedAt': finishedAt.toUtc().toIso8601String(),
      'exerciseIds': exerciseClientIds.map(clientRef).toList(),
      'sets': sets
          .map((s) => {
                'exerciseId': clientRef(s.exerciseClientId),
                'reps': s.reps,
                'weight': s.weight,
              })
          .toList(),
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
    );
  }
}

final workoutSessionRepositoryProvider = Provider<WorkoutSessionRepository>((ref) {
  return WorkoutSessionRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});

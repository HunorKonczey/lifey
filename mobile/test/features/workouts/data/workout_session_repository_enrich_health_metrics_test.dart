import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';

/// [WorkoutSessionRepository.enrichHealthMetrics] backs the watch-workout
/// summary handler (docs/40-watch-app-plan.md §6.3), which only has
/// {clientId, activeCalories, averageHeartRate, healthWorkoutId} on hand —
/// unlike the Health import flow, it can't supply the session's exercises/
/// sets/rating from in-memory editing state, so it must read-then-resubmit
/// like [WorkoutSessionRepository.rate] does.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<Map<String, dynamic>> lastUpdatePayload() async {
    final ops = await (db.select(db.pendingOperations)
          ..where((t) => t.operation.equals('update')))
        .get();
    return jsonDecode(ops.last.payloadJson) as Map<String, dynamic>;
  }

  test('applies the watch summary fields and preserves rating + exercises/sets', () async {
    final startedAt = DateTime.utc(2026, 7, 10, 18, 5);
    final clientId = await repo.create(
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(minutes: 40)),
      exercises: const [PlannedExerciseInput(exerciseClientId: 'ex-1', targetSets: 3)],
      sets: [
        ExerciseSetInput(
          exerciseClientId: 'ex-1',
          reps: 8,
          weight: 60,
          performedAt: startedAt.add(const Duration(minutes: 5)),
        ),
      ],
      rpe: 7,
      feedbackNote: 'kept me honest',
    );

    await repo.enrichHealthMetrics(
      clientId,
      activeCalories: const Value(410),
      averageHeartRate: const Value(128),
      healthWorkoutId: const Value('watch-uuid-1'),
    );

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.activeCalories, 410);
    expect(row.averageHeartRate, 128);
    expect(row.healthWorkoutId, 'watch-uuid-1');
    // Not this flow's fields — must survive untouched.
    expect(row.rpe, 7);
    expect(row.feedbackNote, 'kept me honest');

    final exercises = await db.select(db.workoutSessionExercises).get();
    final sets = await db.select(db.exerciseSets).get();
    expect(exercises, hasLength(1));
    expect(sets, hasLength(1));

    final payload = await lastUpdatePayload();
    expect(payload['activeCalories'], 410);
    expect(payload['averageHeartRate'], 128);
    expect(payload['healthWorkoutId'], 'watch-uuid-1');
    expect(payload['rpe'], 7);
  });

  test('an absent field is preserved, not cleared', () async {
    final startedAt = DateTime.utc(2026, 7, 10, 18, 5);
    final clientId = await repo.create(
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
      activeCalories: 200,
    );

    await repo.enrichHealthMetrics(
      clientId,
      averageHeartRate: const Value(120),
      healthWorkoutId: const Value('watch-uuid-2'),
    );

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.activeCalories, 200);
    expect(row.averageHeartRate, 120);
    expect(row.healthWorkoutId, 'watch-uuid-2');
  });
}

/// Prevents OutboxWriter's fire-and-forget kick from touching the network —
/// same pattern as workout_session_repository_update_test.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

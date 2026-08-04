import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';

/// The session payload has to carry each planned exercise's `targetSets` — the
/// count the log screen rebuilds its still-blank set rows from. It used to send
/// bare `exerciseIds`, so the value never left the device and every pull
/// brought the session back with those rows gone.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // The outbox's fire-and-forget sync kick must not hit the network — these
    // tests only inspect the queued payloads (see workout_session_repository_update_test).
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<Map<String, dynamic>> lastPayload(String operation) async {
    final ops = await (db.select(db.pendingOperations)
          ..where((t) => t.operation.equals(operation)))
        .get();
    return jsonDecode(ops.last.payloadJson) as Map<String, dynamic>;
  }

  const exercises = [
    PlannedExerciseInput(exerciseClientId: 'ex-bench', targetSets: 3),
    PlannedExerciseInput(exerciseClientId: 'ex-squat'),
  ];

  test('create sends each planned exercise with its targetSets', () async {
    await repo.create(
      startedAt: DateTime.utc(2026, 7, 10, 17),
      exercises: exercises,
      sets: const [],
    );

    final payload = await lastPayload('create');
    final planned = (payload['plannedExercises'] as List).cast<Map<String, dynamic>>();
    expect(planned, hasLength(2));
    expect(planned.first['targetSets'], 3);
    // An exercise with no plan omits the key rather than sending a null — same
    // shape as every other optional field in this payload.
    expect(planned.last.containsKey('targetSets'), isFalse);
  });

  test('the exercise ids travel as clientRefs the sync engine can resolve', () async {
    await repo.create(
      startedAt: DateTime.utc(2026, 7, 10, 17),
      exercises: exercises,
      sets: const [],
    );

    final payload = await lastPayload('create');
    final planned = (payload['plannedExercises'] as List).cast<Map<String, dynamic>>();
    // Whatever `clientRef` produces, both lists must produce the *same*
    // reference for the same exercise — the resolver rewrites them alike.
    expect(
      planned.map((e) => e['exerciseId']).toList(),
      (payload['exerciseIds'] as List).toList(),
    );
  });

  test('exerciseIds is still sent alongside it', () async {
    // The backend still requires it, and a server build older than
    // plannedExercises reads only that one.
    await repo.create(
      startedAt: DateTime.utc(2026, 7, 10, 17),
      exercises: exercises,
      sets: const [],
    );

    final payload = await lastPayload('create');
    expect(payload['exerciseIds'], hasLength(2));
  });

  test('update sends the grown plan, not the one the session started with', () async {
    final startedAt = DateTime.utc(2026, 7, 10, 17);
    final clientId = await repo.create(
      startedAt: startedAt,
      exercises: exercises,
      sets: const [],
    );

    // "+ Add set" on the bench block: the plan is now 4 rows.
    await repo.update(
      clientId,
      startedAt: startedAt,
      exercises: const [
        PlannedExerciseInput(exerciseClientId: 'ex-bench', targetSets: 4),
        PlannedExerciseInput(exerciseClientId: 'ex-squat'),
      ],
      sets: const [],
    );

    final payload = await lastPayload('update');
    final planned = (payload['plannedExercises'] as List).cast<Map<String, dynamic>>();
    expect(planned.first['targetSets'], 4);
  });
}

/// Swallows the outbox's `_kick()` so no HTTP is attempted.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

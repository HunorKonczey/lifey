import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';

/// C2.1: `movingSinceEpochMs` — the live `CardioSessionScreen`'s epoch
/// checkpoint (docs/cardio/59-cardio-implementation-plan.md C2.1). Mirrors
/// the structure of `workout_session_repository_cardio_test.dart`'s
/// payload-shape regression tests: the critical, silent-failure-prone
/// property here is that this field is **client-only** — a leak into the
/// outbox payload would be a silent contract break with the backend (which
/// has no matching column), not caught by anything except a test that
/// actually inspects the payload keys.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<Map<String, dynamic>> lastPayload(String operation) async {
    final ops = await (db.select(db.pendingOperations)
          ..where((t) => t.operation.equals(operation)))
        .get();
    return jsonDecode(ops.last.payloadJson) as Map<String, dynamic>;
  }

  test('create persists movingSinceEpochMs locally but never in the payload', () async {
    final clientId = await repo.create(
      startedAt: DateTime.utc(2026, 8, 11, 7),
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
      movingSeconds: 0,
      movingSinceEpochMs: 1786000000000,
    );

    final row = await (db.select(db.workoutSessions)..where((t) => t.clientId.equals(clientId)))
        .getSingle();
    expect(row.movingSinceEpochMs, 1786000000000);

    final payload = await lastPayload('create');
    expect(payload.containsKey('movingSinceEpochMs'), isFalse);
  });

  test('update can set movingSinceEpochMs (resume) without touching the payload', () async {
    final clientId = await repo.create(
      startedAt: DateTime.utc(2026, 8, 11, 7),
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
      movingSeconds: 300,
    );

    await repo.update(
      clientId,
      startedAt: DateTime.utc(2026, 8, 11, 7),
      exercises: const [],
      sets: const [],
      movingSinceEpochMs: const Value(1786000300000),
    );

    final row = await (db.select(db.workoutSessions)..where((t) => t.clientId.equals(clientId)))
        .getSingle();
    expect(row.movingSinceEpochMs, 1786000300000);
    expect(row.movingSeconds, 300); // untouched — absent stays absent

    final payload = await lastPayload('update');
    expect(payload.containsKey('movingSinceEpochMs'), isFalse);
  });

  test('update can clear movingSinceEpochMs (pause) explicitly', () async {
    final clientId = await repo.create(
      startedAt: DateTime.utc(2026, 8, 11, 7),
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
      movingSeconds: 0,
      movingSinceEpochMs: 1786000000000,
    );

    await repo.update(
      clientId,
      startedAt: DateTime.utc(2026, 8, 11, 7),
      exercises: const [],
      sets: const [],
      movingSeconds: const Value(754),
      movingSinceEpochMs: const Value(null),
    );

    final row = await (db.select(db.workoutSessions)..where((t) => t.clientId.equals(clientId)))
        .getSingle();
    expect(row.movingSeconds, 754);
    expect(row.movingSinceEpochMs, isNull);
  });

  test('an update that never mentions movingSinceEpochMs preserves whatever was there', () async {
    final clientId = await repo.create(
      startedAt: DateTime.utc(2026, 8, 11, 7),
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
      movingSeconds: 0,
      movingSinceEpochMs: 1786000000000,
    );

    // Mirrors rate()/enrichHealthMetrics() calling update() without any
    // opinion on the live-session checkpoint — must not silently wipe it.
    await repo.update(
      clientId,
      startedAt: DateTime.utc(2026, 8, 11, 7),
      exercises: const [],
      sets: const [],
      rpe: const Value(7),
    );

    final row = await (db.select(db.workoutSessions)..where((t) => t.clientId.equals(clientId)))
        .getSingle();
    expect(row.movingSinceEpochMs, 1786000000000);
  });

}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

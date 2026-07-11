import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';

/// Regression tests for the mutual-wipe bug between the two session
/// enrichment flows: rating a session (rpe/feedbackNote) used to disconnect
/// its paired Apple Health workout, and pairing a Health workout used to
/// erase an already-saved rating. Both the local row and the outbox payload
/// matter — the backend update is a full replace, so a payload missing a
/// field clears it server-side with a clean 200.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // The outbox's fire-and-forget sync kick must not hit the network — these
    // tests only inspect the queued payloads (see food_update_http_method_test).
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<Map<String, dynamic>> lastUpdatePayload() async {
    final ops = await (db.select(db.pendingOperations)
          ..where((t) => t.operation.equals('update')))
        .get();
    return jsonDecode(ops.last.payloadJson) as Map<String, dynamic>;
  }

  test('rating a session preserves its paired Health workout data', () async {
    final startedAt = DateTime.utc(2026, 7, 10, 17);
    final clientId = await repo.create(
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(hours: 1)),
      exercises: const [],
      sets: const [],
      activeCalories: 320,
      averageHeartRate: 131,
      healthWorkoutId: 'hk-uuid-1',
    );

    // The session editor's save: it owns rpe/feedbackNote but has no health
    // state, so those fields are absent — they must survive.
    await repo.update(
      clientId,
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(hours: 1)),
      exercises: const [],
      sets: const [],
      rpe: const Value(7),
      feedbackNote: const Value('tough one'),
    );

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.healthWorkoutId, 'hk-uuid-1');
    expect(row.activeCalories, 320);
    expect(row.averageHeartRate, 131);
    expect(row.rpe, 7);

    final payload = await lastUpdatePayload();
    expect(payload['healthWorkoutId'], 'hk-uuid-1');
    expect(payload['activeCalories'], 320);
    expect(payload['averageHeartRate'], 131);
    expect(payload['rpe'], 7);
    expect(payload['feedbackNote'], 'tough one');
  });

  test('pairing a Health workout preserves an already-saved rating', () async {
    final startedAt = DateTime.utc(2026, 7, 10, 17);
    final clientId = await repo.create(
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(hours: 1)),
      exercises: const [],
      sets: const [],
      rpe: 8,
      feedbackNote: 'note',
    );

    // The Health import's save: it owns the health fields but not the rating.
    await repo.update(
      clientId,
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(hours: 1)),
      exercises: const [],
      sets: const [],
      activeCalories: const Value(280),
      averageHeartRate: const Value(124),
      healthWorkoutId: const Value('hk-uuid-2'),
    );

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.rpe, 8);
    expect(row.feedbackNote, 'note');
    expect(row.healthWorkoutId, 'hk-uuid-2');

    final payload = await lastUpdatePayload();
    expect(payload['rpe'], 8);
    expect(payload['feedbackNote'], 'note');
    expect(payload['healthWorkoutId'], 'hk-uuid-2');
  });

  test('an explicit Value(null) still clears a field', () async {
    final startedAt = DateTime.utc(2026, 7, 10, 17);
    final clientId = await repo.create(
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
      rpe: 5,
      feedbackNote: 'delete me',
    );

    // Editing the rating and erasing the note must actually clear it —
    // "absent means keep" must not swallow deliberate nulls.
    await repo.update(
      clientId,
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
      rpe: const Value(6),
      feedbackNote: const Value(null),
    );

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.rpe, 6);
    expect(row.feedbackNote, isNull);

    final payload = await lastUpdatePayload();
    expect(payload['rpe'], 6);
    expect(payload.containsKey('feedbackNote'), isFalse);
  });
}

/// Prevents OutboxWriter's fire-and-forget kick from touching the network —
/// same pattern as food_update_http_method_test.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

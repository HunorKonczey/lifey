import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';

/// [WorkoutSessionRepository.create]'s optional `clientId` and
/// [WorkoutSessionRepository.existsByClientId] back the standalone-session
/// processor's idempotency check (docs/watch/44-watch-f6-standalone-plan.md
/// §4.1, D-F6.2, D-F6.3) — a retried watch delivery must resolve to the same
/// local session, not a duplicate.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  test('create(clientId:) uses the supplied id instead of generating one', () async {
    final startedAt = DateTime.utc(2026, 7, 26, 7);

    final returnedId = await repo.create(
      clientId: 'standalone-1',
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(minutes: 30)),
      exercises: const [],
      sets: const [],
    );

    expect(returnedId, 'standalone-1');
    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.clientId, 'standalone-1');
  });

  test('create() without clientId still generates one (existing behavior unchanged)', () async {
    final startedAt = DateTime.utc(2026, 7, 26, 7);

    final returnedId = await repo.create(
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
    );

    expect(returnedId, isNotEmpty);
    expect(await repo.existsByClientId(returnedId), isTrue);
  });

  test('existsByClientId reflects the created session and is false for an unknown id', () async {
    final startedAt = DateTime.utc(2026, 7, 26, 7);

    expect(await repo.existsByClientId('standalone-1'), isFalse);

    await repo.create(
      clientId: 'standalone-1',
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
    );

    expect(await repo.existsByClientId('standalone-1'), isTrue);
    expect(await repo.existsByClientId('some-other-id'), isFalse);
  });

  test('the outbox create payload is enqueued under the supplied clientId', () async {
    final startedAt = DateTime.utc(2026, 7, 26, 7);

    await repo.create(
      clientId: 'standalone-1',
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
    );

    final ops = await (db.select(db.pendingOperations)
          ..where((t) => t.operation.equals('create')))
        .get();
    expect(ops, hasLength(1));
    expect(ops.single.clientId, 'standalone-1');
    final payload = jsonDecode(ops.single.payloadJson) as Map<String, dynamic>;
    expect(payload['startedAt'], isNotNull);
  });
}

/// Prevents OutboxWriter's fire-and-forget kick from touching the network —
/// same pattern as workout_session_repository_update_test.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

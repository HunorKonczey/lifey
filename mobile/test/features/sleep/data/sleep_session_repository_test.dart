import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/sleep/data/sleep_session_repository.dart';

/// The outbox kicks a drain after every enqueue; in a unit test that would run
/// against a database the tearDown has already closed.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

/// docs/integrations/89 G2.2 (D-G7): the local-first sleep session store.
void main() {
  late AppDatabase db;
  late SleepSessionRepository repo;

  final start = DateTime.utc(2026, 11, 20, 22, 40);
  final end = DateTime.utc(2026, 11, 21, 6, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SleepSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<void> insertSynced(String clientId, int serverId, DateTime startedAt, DateTime endedAt) =>
      db.into(db.sleepSessions).insert(SleepSessionsCompanion.insert(
            clientId: clientId,
            serverId: Value(serverId),
            startedAt: startedAt,
            endedAt: endedAt,
          ));

  test('create stores the row and enqueues a create with the UTC wire payload', () async {
    final clientId = await repo.create(
      startedAt: start,
      endedAt: end,
      asleepMinutes: 420,
      deepMinutes: 80,
      lightMinutes: 230,
      remMinutes: 110,
      awakeMinutes: 30,
      sourceAppName: ' Garmin Connect ',
      healthRecordId: 'hc-sleep-1',
    );

    final row = await db.select(db.sleepSessions).getSingle();
    expect(row.clientId, clientId);
    expect(row.serverId, isNull);
    expect(row.deepMinutes, 80);
    expect(row.sourceAppName, 'Garmin Connect');

    final op = await db.select(db.pendingOperations).getSingle();
    expect(op.entityType, 'sleep_session');
    expect(op.operation, 'create');
    expect(op.clientId, clientId);
    expect(jsonDecode(op.payloadJson), {
      'startedAt': '2026-11-20T22:40:00.000Z',
      'endedAt': '2026-11-21T06:10:00.000Z',
      'asleepMinutes': 420,
      'deepMinutes': 80,
      'lightMinutes': 230,
      'remMinutes': 110,
      'awakeMinutes': 30,
      'sourceAppName': 'Garmin Connect',
      'healthRecordId': 'hc-sleep-1',
    });
  });

  test('a session without stages or provenance sends only its times', () async {
    await repo.create(startedAt: start, endedAt: end, sourceAppName: '  ', healthRecordId: '');

    final row = await db.select(db.sleepSessions).getSingle();
    expect(row.deepMinutes, isNull);
    expect(row.sourceAppName, isNull);
    expect(row.healthRecordId, isNull);
    final op = await db.select(db.pendingOperations).getSingle();
    expect(jsonDecode(op.payloadJson), {
      'startedAt': '2026-11-20T22:40:00.000Z',
      'endedAt': '2026-11-21T06:10:00.000Z',
    });
  });

  test('deleting a never-synced session drops the row and queues nothing to the server', () async {
    final clientId = await repo.create(startedAt: start, endedAt: end);

    await repo.delete(clientId);

    expect(await db.select(db.sleepSessions).get(), isEmpty);
    expect(await db.select(db.pendingOperations).get(), isEmpty);
  });

  test('deleting a synced session keeps the row, hides it from watchAll and queues a delete', () async {
    await insertSynced('c1', 42, start, end);

    await repo.delete('c1');

    expect(await db.select(db.sleepSessions).get(), hasLength(1));
    expect(await repo.watchAll().first, isEmpty);
    final op = await db.select(db.pendingOperations).getSingle();
    expect(op.operation, 'delete');
    expect(op.entityType, 'sleep_session');
  });

  test('watchAll lists the newest wake-up first and maps every field', () async {
    await insertSynced('older', 1, start.subtract(const Duration(days: 1)), end.subtract(const Duration(days: 1)));
    await repo.create(startedAt: start, endedAt: end, remMinutes: 95, healthRecordId: 'hc-2');

    final sessions = await repo.watchAll().first;

    expect(sessions.map((s) => s.clientId).last, 'older');
    expect(sessions.first.remMinutes, 95);
    expect(sessions.first.healthRecordId, 'hc-2');
    expect(sessions.first.id, isNull);
    expect(sessions.last.id, 1);
  });

  test('existsByHealthRecordId finds only an imported record', () async {
    await repo.create(startedAt: start, endedAt: end, healthRecordId: 'hc-sleep-1');

    expect(await repo.existsByHealthRecordId('hc-sleep-1'), isTrue);
    expect(await repo.existsByHealthRecordId('hc-sleep-2'), isFalse);
  });
}

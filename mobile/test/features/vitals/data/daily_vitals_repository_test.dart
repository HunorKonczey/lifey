import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/vitals/data/daily_vitals_repository.dart';
import 'package:lifey/features/vitals/domain/daily_vitals.dart';

/// The outbox kicks a drain after every enqueue; in a unit test that would run
/// against a database the tearDown has already closed.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

/// docs/integrations/89 G3.2 (D-G8): the local-first daily vitals store, one
/// row per day, values merged as they arrive.
void main() {
  late AppDatabase db;
  late DailyVitalsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DailyVitalsRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<List<Map<String, dynamic>>> payloads(String operation) async {
    final ops = await (db.select(db.pendingOperations)..where((t) => t.operation.equals(operation))).get();
    return [for (final op in ops) jsonDecode(op.payloadJson) as Map<String, dynamic>];
  }

  test('the first value of a day creates the row and queues a create with the day', () async {
    await repo.upsertForDay(date: DateTime(2026, 11, 21, 7, 30), restingHr: 52);

    final row = await db.select(db.dailyVitalsTable).getSingle();
    expect(row.date, DateTime(2026, 11, 21));
    expect(row.restingHr, 52);
    expect(row.hrvMs, isNull);
    final op = await db.select(db.pendingOperations).getSingle();
    expect(op.entityType, 'daily_vitals');
    expect(op.operation, 'create');
    expect(jsonDecode(op.payloadJson), {'date': '2026-11-21', 'restingHr': 52});
  });

  test('a later value of the same day merges in, and the payload carries the whole day', () async {
    await db.into(db.dailyVitalsTable).insert(DailyVitalsTableCompanion.insert(
          clientId: 'd1',
          serverId: const Value(7),
          date: DateTime(2026, 11, 21),
          restingHr: const Value(52),
        ));

    await repo.upsertForDay(date: DateTime(2026, 11, 21, 23), hrvMs: 48.5, hrvMethod: HrvMethod.rmssd);

    final row = await db.select(db.dailyVitalsTable).getSingle();
    expect(row.restingHr, 52);
    expect(row.hrvMs, 48.5);
    expect(row.hrvMethod, 'RMSSD');
    expect((await payloads('update')).single,
        {'date': '2026-11-21', 'restingHr': 52, 'hrvMs': 48.5, 'hrvMethod': 'RMSSD'});
  });

  test('an unchanged day queues nothing, and a call without values does nothing', () async {
    await db.into(db.dailyVitalsTable).insert(DailyVitalsTableCompanion.insert(
          clientId: 'd1',
          serverId: const Value(7),
          date: DateTime(2026, 11, 21),
          restingHr: const Value(52),
        ));

    await repo.upsertForDay(date: DateTime(2026, 11, 21), restingHr: 52);
    await repo.upsertForDay(date: DateTime(2026, 11, 22));

    expect(await db.select(db.pendingOperations).get(), isEmpty);
    expect(await db.select(db.dailyVitalsTable).get(), hasLength(1));
  });

  test('deleting a never-synced day drops the row and queues nothing to the server', () async {
    await repo.upsertForDay(date: DateTime(2026, 11, 21), restingHr: 52);
    final clientId = (await db.select(db.dailyVitalsTable).getSingle()).clientId;

    await repo.delete(clientId);

    expect(await db.select(db.dailyVitalsTable).get(), isEmpty);
    expect(await db.select(db.pendingOperations).get(), isEmpty);
  });

  test('deleting a synced day keeps the row, hides it from watchAll and queues a delete', () async {
    await db.into(db.dailyVitalsTable).insert(DailyVitalsTableCompanion.insert(
          clientId: 'd1',
          serverId: const Value(7),
          date: DateTime(2026, 11, 21),
          restingHr: const Value(52),
        ));

    await repo.delete('d1');

    expect(await db.select(db.dailyVitalsTable).get(), hasLength(1));
    expect(await repo.watchAll().first, isEmpty);
    expect((await db.select(db.pendingOperations).getSingle()).operation, 'delete');
  });

  test('watchAll is newest first and maps the method', () async {
    await repo.upsertForDay(date: DateTime(2026, 11, 20), restingHr: 54);
    await repo.upsertForDay(date: DateTime(2026, 11, 21), hrvMs: 40, hrvMethod: HrvMethod.sdnn);

    final days = await repo.watchAll().first;

    expect(days.map((d) => d.date), [DateTime(2026, 11, 21), DateTime(2026, 11, 20)]);
    expect(days.first.hrvMethod, HrvMethod.sdnn);
    expect(days.last.restingHr, 54);
  });
}

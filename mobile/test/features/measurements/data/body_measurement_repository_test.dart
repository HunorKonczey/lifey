import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/measurements/data/body_measurement_repository.dart';
import 'package:lifey/features/measurements/domain/body_measurement.dart';

/// The outbox kicks a drain after every enqueue; in a unit test that would run
/// against a database the tearDown has already closed.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

void main() {
  late AppDatabase db;
  late BodyMeasurementRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = BodyMeasurementRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  test('create stores the row locally and enqueues a create with the wire payload', () async {
    await repo.create(date: DateTime(2026, 6, 18), site: MeasurementSite.waist, valueCm: 82.5);

    final rows = await db.select(db.bodyMeasurements).get();
    expect(rows, hasLength(1));
    expect(rows.single.site, 'WAIST');
    expect(rows.single.serverId, isNull);

    final ops = await db.select(db.pendingOperations).get();
    expect(ops, hasLength(1));
    expect(ops.single.entityType, 'body_measurement');
    expect(ops.single.operation, 'create');
    expect(ops.single.clientId, rows.single.clientId);
    expect(jsonDecode(ops.single.payloadJson), {'date': '2026-06-18', 'site': 'WAIST', 'valueCm': 82.5});
  });

  test('deleting a never-synced entry drops the row and queues nothing to the server', () async {
    await repo.create(date: DateTime(2026, 6, 18), site: MeasurementSite.arm, valueCm: 35);
    final clientId = (await db.select(db.bodyMeasurements).getSingle()).clientId;

    await repo.delete(clientId);

    expect(await db.select(db.bodyMeasurements).get(), isEmpty);
    final ops = await db.select(db.pendingOperations).get();
    expect(ops.where((o) => o.operation == 'delete'), isEmpty);
  });

  test('deleting a synced entry keeps the row, hides it from watchAll and queues a delete', () async {
    await db.into(db.bodyMeasurements).insert(BodyMeasurementsCompanion.insert(
          clientId: 'c1',
          serverId: const Value(42),
          date: DateTime(2026, 6, 18),
          site: 'CHEST',
          valueCm: 100,
          recordedAt: DateTime(2026, 6, 18),
        ));

    await repo.delete('c1');

    expect(await db.select(db.bodyMeasurements).get(), hasLength(1));
    expect(await repo.watchAll().first, isEmpty);
    final ops = await db.select(db.pendingOperations).get();
    expect(ops.where((o) => o.operation == 'delete' && o.entityType == 'body_measurement'), hasLength(1));
  });

  test('watchAll is newest-first and skips a site this build does not know', () async {
    Future<void> insert(String id, DateTime date, String site) =>
        db.into(db.bodyMeasurements).insert(BodyMeasurementsCompanion.insert(
              clientId: id,
              date: date,
              site: site,
              valueCm: 50,
              recordedAt: date,
            ));
    await insert('old', DateTime(2026, 6, 1), 'WAIST');
    await insert('new', DateTime(2026, 6, 20), 'THIGH');
    await insert('alien', DateTime(2026, 6, 25), 'ELBOW');

    final list = await repo.watchAll().first;

    expect(list.map((m) => m.clientId), ['new', 'old']);
  });
}

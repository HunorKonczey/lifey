import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';

/// Regression test: a gateway answering 502/503/504 (a deploy, a cold start) used to park
/// the outbox row as a permanent `failed` — only a manual retry from the sync indicator
/// brought it back. Those statuses are "not now", so they are retried like a dropped
/// connection; a real rejection (400/409/500) still stays parked.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.statuses);

  final List<int> statuses;
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = statuses[calls < statuses.length ? calls : statuses.length - 1];
    calls++;
    return ResponseBody.fromString(
      status == 200 ? '{"id": 7}' : '{"message": "boom"}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

void main() {
  late AppDatabase db;
  late Dio dio;
  late OutboxWriter writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test', validateStatus: (s) => s != null && s < 300));
    writer = OutboxWriter(db, _NoopSyncEngine(db, dio));
  });

  tearDown(() => db.close());

  Future<void> enqueueWeight() => writer.enqueueCreate(
        clientId: 'c1',
        entityType: 'weight_entry',
        payload: {'weight': 80.0},
      );

  for (final status in [401, 408, 429, 502, 503, 504]) {
    test('a $status is parked as a network failure and retried on the next drain', () async {
      final adapter = _ScriptedAdapter([status, 200]);
      dio.httpClientAdapter = adapter;
      final engine = SyncEngine(db, dio);
      await enqueueWeight();

      await engine.sync();
      final parked = await db.select(db.pendingOperations).getSingle();
      expect(parked.status, 'failed');
      expect(parked.lastError, startsWith('[network] '));

      await engine.sync();
      expect(adapter.calls, 2);
      expect(await db.select(db.pendingOperations).get(), isEmpty);
    });
  }

  for (final status in [400, 403, 404, 409, 500]) {
    test('a $status stays parked until someone retries it', () async {
      final adapter = _ScriptedAdapter([status, 200]);
      dio.httpClientAdapter = adapter;
      final engine = SyncEngine(db, dio);
      await enqueueWeight();

      await engine.sync();
      await engine.sync();

      expect(adapter.calls, 1);
      final parked = await db.select(db.pendingOperations).getSingle();
      expect(parked.status, 'failed');
      expect(parked.lastError, isNot(startsWith('[network]')));
    });
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/sleep/data/sleep_session_repository.dart';

/// docs/integrations/89 D-G7, the sleep counterpart of D-G3: the server
/// answers a second import of the same health-store record with 409 (a
/// reinstall, another device, or a night the user deleted). The local copy is
/// a duplicate and is dropped instead of parked as a failure. A 409 on a
/// session without a record id stays visible.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.status);

  final int status;
  final requests = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    return ResponseBody.fromString(
      status == 201 ? jsonEncode({'id': 7}) : '{"message": "Sleep session already imported: hc-sleep-1"}',
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
  late SleepSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test', validateStatus: (s) => s != null && s < 300));
    repo = SleepSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, dio)));
  });

  tearDown(() => db.close());

  Future<void> createNight({String? recordId}) => repo.create(
        startedAt: DateTime.utc(2026, 11, 20, 22, 40),
        endedAt: DateTime.utc(2026, 11, 21, 6, 10),
        healthRecordId: recordId,
      );

  test('a successful create posts to /sleep-sessions and stores the server id', () async {
    final adapter = _RecordingAdapter(201);
    dio.httpClientAdapter = adapter;
    await createNight(recordId: 'hc-sleep-1');

    await SyncEngine(db, dio).sync();

    expect(adapter.requests, ['POST /sleep-sessions']);
    expect(await db.select(db.pendingOperations).get(), isEmpty);
    expect((await db.select(db.sleepSessions).getSingle()).serverId, 7);
  });

  test('a 409 on an imported night drops the local duplicate and its ops', () async {
    dio.httpClientAdapter = _RecordingAdapter(409);
    await createNight(recordId: 'hc-sleep-1');

    await SyncEngine(db, dio).sync();

    expect(await db.select(db.pendingOperations).get(), isEmpty);
    expect(await db.select(db.sleepSessions).get(), isEmpty);
  });

  test('a 409 on a session without a record id stays a visible failure', () async {
    dio.httpClientAdapter = _RecordingAdapter(409);
    await createNight();

    await SyncEngine(db, dio).sync();

    final parked = await db.select(db.pendingOperations).getSingle();
    expect(parked.status, 'failed');
    expect(await db.select(db.sleepSessions).get(), hasLength(1));
  });
}

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/vitals/data/daily_vitals_repository.dart';
import 'package:lifey/features/vitals/domain/daily_vitals.dart';

/// docs/integrations/89 G3.2: what the sync engine sends for daily vitals — a
/// POST for a new day, a PUT on the server id once the day exists there.
class _RecordingAdapter implements HttpClientAdapter {
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
      '{"id": 7}',
      options.method == 'POST' ? 201 : 200,
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
  late _RecordingAdapter adapter;
  late DailyVitalsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _RecordingAdapter();
    dio.httpClientAdapter = adapter;
    repo = DailyVitalsRepository(db, OutboxWriter(db, _NoopSyncEngine(db, dio)));
  });

  tearDown(() => db.close());

  test('a new day posts to /vitals, a later value of it puts to /vitals/{id}', () async {
    await repo.upsertForDay(date: DateTime(2026, 11, 21), restingHr: 52);
    await SyncEngine(db, dio).sync();

    expect((await db.select(db.dailyVitalsTable).getSingle()).serverId, 7);

    await repo.upsertForDay(date: DateTime(2026, 11, 21), hrvMs: 48.5, hrvMethod: HrvMethod.rmssd);
    await SyncEngine(db, dio).sync();

    expect(adapter.requests, ['POST /vitals', 'PUT /vitals/7']);
    expect(await db.select(db.pendingOperations).get(), isEmpty);
  });
}

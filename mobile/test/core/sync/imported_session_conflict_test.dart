import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// docs/integrations/89 D-G3: the server answers a second import of the same
/// health-store record with 409, for example after a reinstall or when the
/// user deleted that session. The local copy is then a duplicate. It is
/// dropped together with its children and pending ops, instead of being
/// parked as a failure. A 409 on any other create stays visible.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      status == 200 ? '{"id": 7}' : '{"message": "Health workout already imported: hc-run-1"}',
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
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test', validateStatus: (s) => s != null && s < 300));
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, dio)));
  });

  tearDown(() => db.close());

  Future<String> createSession({String? importSource}) => repo.create(
        startedAt: DateTime.utc(2026, 11, 20, 6),
        finishedAt: DateTime.utc(2026, 11, 20, 6, 42),
        exercises: const [],
        sets: const [],
        healthWorkoutId: 'hc-run-1',
        importSource: importSource,
        importAppName: importSource == null ? null : 'Garmin Connect',
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        cardio: const CardioMetrics(distanceMeters: 8120),
      );

  test('a 409 on an imported session create drops the local duplicate and its ops', () async {
    dio.httpClientAdapter = _StatusAdapter(409);
    final clientId = await createSession(importSource: 'HEALTH');

    await SyncEngine(db, dio).sync();

    expect(await db.select(db.pendingOperations).get(), isEmpty);
    expect(await repo.findByClientId(clientId), isNull);
    expect(await db.select(db.cardioDetails).get(), isEmpty);
  });

  test('a 409 on a Lifey-recorded session create stays a visible failure', () async {
    dio.httpClientAdapter = _StatusAdapter(409);
    final clientId = await createSession();

    await SyncEngine(db, dio).sync();

    final parked = await db.select(db.pendingOperations).getSingle();
    expect(parked.status, 'failed');
    expect(parked.lastError, contains('already imported'));
    expect(await repo.findByClientId(clientId), isNotNull);
  });

  test('any other failure of an imported create is parked as usual', () async {
    dio.httpClientAdapter = _StatusAdapter(400);
    final clientId = await createSession(importSource: 'HEALTH');

    await SyncEngine(db, dio).sync();

    expect((await db.select(db.pendingOperations).getSingle()).status, 'failed');
    expect(await repo.findByClientId(clientId), isNotNull);
  });

  test('a successful imported create syncs normally', () async {
    dio.httpClientAdapter = _StatusAdapter(200);
    final clientId = await createSession(importSource: 'HEALTH');

    await SyncEngine(db, dio).sync();

    expect(await db.select(db.pendingOperations).get(), isEmpty);
    expect((await repo.findByClientId(clientId))!.id, 7);
  });
}

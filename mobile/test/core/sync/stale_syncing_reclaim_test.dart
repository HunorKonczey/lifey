import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// Regression test for a permanently stranded outbox row.
///
/// [SyncEngine] flips an operation to `syncing` for exactly as long as its
/// request is in flight. If the process dies in that window — a long cardio
/// session backgrounded with GPS is the realistic way to get there — the row
/// stays `syncing` forever: nothing reset it, and the drain query only ever
/// picked up `pending`/network-`failed` rows. The entity then never reached
/// the backend again, because every later update for the same clientId waits
/// behind its unsynced create — and it showed as the neutral "syncing…"
/// marker rather than a failure, so there was no error to see and nothing to
/// retry from the UI.
class _RecordingAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];
  int _nextId = 1;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    paths.add(options.path);
    return ResponseBody.fromString(
      options.method == 'POST' ? '{"id": ${_nextId++}}' : '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// See `food_update_http_method_test.dart` — keeps the writer's own
/// fire-and-forget kick from racing the test's explicit drains.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

void main() {
  late AppDatabase db;
  late Dio dio;
  late _RecordingAdapter adapter;
  late SyncEngine syncEngine;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _RecordingAdapter();
    dio.httpClientAdapter = adapter;
    syncEngine = SyncEngine(db, dio);
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, dio)));
  });

  tearDown(() => db.close());

  /// Stands in for "the app was killed mid-request": exactly the state
  /// [SyncEngine] leaves behind when it never gets to finish an operation.
  Future<void> simulateKillDuringRequest() async {
    await db.update(db.pendingOperations).write(
          const PendingOperationsCompanion(status: Value('syncing')),
        );
  }

  test('an operation left mid-flight by a killed run is retried, not stranded',
      () async {
    final startedAt = DateTime.now();
    await repo.create(
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'WALKING',
      movingSeconds: 0,
      movingSinceEpochMs: startedAt.millisecondsSinceEpoch,
    );
    await simulateKillDuringRequest();

    await syncEngine.sync();

    expect(adapter.methods, ['POST']);
    expect(adapter.paths, ['/workout-sessions']);
    expect(await db.select(db.pendingOperations).get(), isEmpty);
  });

  test('the whole session still syncs after the create was left mid-flight',
      () async {
    final startedAt = DateTime.now();
    final clientId = await repo.create(
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'WALKING',
      movingSeconds: 0,
      movingSinceEpochMs: startedAt.millisecondsSinceEpoch,
    );
    await simulateKillDuringRequest();

    // Finishing the walk queues an update behind that stranded create.
    await repo.update(
      clientId,
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(minutes: 30)),
      exercises: const [],
      sets: const [],
      movingSeconds: const Value(1800),
      movingSinceEpochMs: const Value(null),
      cardio: const Value(CardioMetrics(distanceMeters: 2500, distanceSource: 'MEASURED')),
    );

    await syncEngine.sync();

    expect(adapter.methods, ['POST', 'PUT']);
    expect(adapter.paths, ['/workout-sessions', '/workout-sessions/1']);
    expect(await db.select(db.pendingOperations).get(), isEmpty);
    final row = await (db.select(db.workoutSessions)
          ..where((t) => t.clientId.equals(clientId)))
        .getSingle();
    expect(row.serverId, 1);
  });
}

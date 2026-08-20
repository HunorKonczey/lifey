import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// docs/cardio/60 C8.4 — a session's marked waypoints round-trip through the
/// local DB and the outbox payload exactly like `CardioSplit`
/// (`workout_session_repository_cardio_test.dart` is the template this
/// mirrors), full-replace on every save.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<Map<String, dynamic>> lastPayload(String operation) async {
    final ops = await (db.select(db.pendingOperations)
          ..where((t) => t.operation.equals(operation)))
        .get();
    return jsonDecode(ops.last.payloadJson) as Map<String, dynamic>;
  }

  const waypoints = [
    CardioWaypoint(waypointIndex: 0, latitude: 47.5, longitude: 19.05, altitudeMeters: 612),
    CardioWaypoint(waypointIndex: 1, latitude: 47.51, longitude: 19.06),
  ];

  test('create persists waypoints locally, ordered', () async {
    final clientId = await repo.create(
      startedAt: DateTime.utc(2026, 8, 19, 7),
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'HIKING',
      movingSeconds: 3600,
      waypoints: waypoints,
    );

    final rows = await (db.select(db.cardioWaypoints)
          ..where((t) => t.sessionClientId.equals(clientId))
          ..orderBy([(t) => OrderingTerm.asc(t.waypointIndex)]))
        .get();
    expect(rows, hasLength(2));
    expect(rows[0].latitude, 47.5);
    expect(rows[0].altitudeMeters, 612);
    expect(rows[1].altitudeMeters, isNull);
  });

  test('create sends every waypoint in the payload, field order matching CardioWaypointRequest',
      () async {
    await repo.create(
      startedAt: DateTime.utc(2026, 8, 19, 7),
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'HIKING',
      waypoints: waypoints,
    );

    final payload = await lastPayload('create');
    final waypointsJson = (payload['waypoints'] as List).cast<Map<String, dynamic>>();
    expect(waypointsJson, hasLength(2));
    expect(waypointsJson[0]['waypointIndex'], 0);
    expect(waypointsJson[0]['latitude'], 47.5);
    expect(waypointsJson[0]['altitudeMeters'], 612);
    expect(waypointsJson[0]['label'], isNull);
    expect(waypointsJson[1]['altitudeMeters'], isNull);
  });

  test('a session with no waypoints omits the key entirely', () async {
    await repo.create(
      startedAt: DateTime.utc(2026, 8, 19, 7),
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
    );

    final payload = await lastPayload('create');
    expect(payload.containsKey('waypoints'), isFalse);
  });

  test('watchAll reads waypoints back in waypointIndex order', () async {
    await repo.create(
      startedAt: DateTime.utc(2026, 8, 19, 7),
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'HIKING',
      // Inserted out of order — the read must still come back sorted.
      waypoints: const [
        CardioWaypoint(waypointIndex: 1, latitude: 47.51, longitude: 19.06),
        CardioWaypoint(waypointIndex: 0, latitude: 47.5, longitude: 19.05, altitudeMeters: 612),
      ],
    );

    final session = (await repo.watchAll().first).single;
    expect(session.waypoints, hasLength(2));
    expect(session.waypoints[0].waypointIndex, 0);
    expect(session.waypoints[0].altitudeMeters, 612);
    expect(session.waypoints[1].waypointIndex, 1);
  });

  test('update replaces the waypoint list, not appends (a mid-session mark)', () async {
    final startedAt = DateTime.utc(2026, 8, 19, 7);
    final clientId = await repo.create(
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'HIKING',
      waypoints: waypoints.take(1).toList(),
    );

    await repo.update(
      clientId,
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
      waypoints: const Value(waypoints),
    );

    final rows = await (db.select(db.cardioWaypoints)
          ..where((t) => t.sessionClientId.equals(clientId)))
        .get();
    expect(rows, hasLength(2));
  });

  test('update with an absent waypoints Value preserves what was already stored', () async {
    final startedAt = DateTime.utc(2026, 8, 19, 7);
    final clientId = await repo.create(
      startedAt: startedAt,
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'HIKING',
      waypoints: waypoints,
    );

    // Rating the session doesn't own waypoints — must not wipe them.
    await repo.rate(clientId, rpe: 6);

    final rows = await (db.select(db.cardioWaypoints)
          ..where((t) => t.sessionClientId.equals(clientId)))
        .get();
    expect(rows, hasLength(2));
  });

  test('deleting a session cleans up its waypoints too', () async {
    final clientId = await repo.create(
      startedAt: DateTime.utc(2026, 8, 19, 7),
      exercises: const [],
      sets: const [],
      sessionKind: 'CARDIO',
      activityType: 'HIKING',
      waypoints: waypoints,
    );

    await repo.delete(clientId);

    final rows = await (db.select(db.cardioWaypoints)
          ..where((t) => t.sessionClientId.equals(clientId)))
        .get();
    expect(rows, isEmpty);
  });
}

/// Same no-network stub `workout_session_repository_cardio_test.dart` uses —
/// these tests only inspect the queued payloads and local DB state.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

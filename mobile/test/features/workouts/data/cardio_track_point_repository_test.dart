import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/cardio_track_point_repository.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';

/// docs/cardio/54-cardio-gps-route-plan.md §4.1, C4a.3 — kész-ha: "Kilőtt
/// app legfeljebb egy pontot veszít" (a killed app loses at most one
/// point). The repository-level guarantee that makes that true is simply
/// that every write is its own immediate insert, never buffered — these
/// tests check that, plus ordering, roundtrip fidelity, and cascade delete.

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

LocationFix _fix({
  required double lat,
  required double lng,
  double? altitude,
  double? accuracy,
  double? speed,
  DateTime? recordedAt,
}) {
  return LocationFix(
    latitude: lat,
    longitude: lng,
    altitude: altitude,
    accuracy: accuracy,
    speed: speed,
    recordedAt: recordedAt ?? DateTime.utc(2026, 8, 12, 7, 0),
  );
}

void main() {
  late AppDatabase db;
  late CardioTrackPointRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CardioTrackPointRepository(db);
  });

  tearDown(() => db.close());

  test('addPoint writes immediately — readable right after, no buffering', () async {
    await repo.addPoint('s1', 0, _fix(lat: 47.5, lng: 19.05));

    final points = await repo.pointsForSession('s1');
    expect(points, hasLength(1));
    expect(points.single.latitude, 47.5);
    expect(points.single.longitude, 19.05);
  });

  test('roundtrips altitude/accuracy/speed, including null', () async {
    await repo.addPoint(
      's1',
      0,
      _fix(lat: 47.5, lng: 19.05, altitude: 112.4, accuracy: 8.2, speed: 3.1),
    );
    await repo.addPoint('s1', 1, _fix(lat: 47.501, lng: 19.051));

    final points = await repo.pointsForSession('s1');
    expect(points[0].altitude, 112.4);
    expect(points[0].accuracy, 8.2);
    expect(points[0].speed, 3.1);
    expect(points[1].altitude, isNull);
    expect(points[1].accuracy, isNull);
    expect(points[1].speed, isNull);
  });

  test('pointsForSession returns points in seq order, not insertion or recordedAt order', () async {
    // Inserted out of both orders on purpose — seq is the only thing that
    // should determine the returned order.
    await repo.addPoint('s1', 2, _fix(lat: 3, lng: 3, recordedAt: DateTime.utc(2026, 8, 12, 7, 0)));
    await repo.addPoint('s1', 0, _fix(lat: 1, lng: 1, recordedAt: DateTime.utc(2026, 8, 12, 7, 2)));
    await repo.addPoint('s1', 1, _fix(lat: 2, lng: 2, recordedAt: DateTime.utc(2026, 8, 12, 7, 1)));

    final points = await repo.pointsForSession('s1');
    expect(points.map((p) => p.seq), [0, 1, 2]);
    expect(points.map((p) => p.latitude), [1, 2, 3]);
  });

  test('pointCount reflects how many points exist for a session', () async {
    expect(await repo.pointCount('s1'), 0);
    await repo.addPoint('s1', 0, _fix(lat: 1, lng: 1));
    await repo.addPoint('s1', 1, _fix(lat: 2, lng: 2));
    expect(await repo.pointCount('s1'), 2);
  });

  test('points are scoped per session — another session\'s points/count are unaffected', () async {
    await repo.addPoint('s1', 0, _fix(lat: 1, lng: 1));
    await repo.addPoint('s2', 0, _fix(lat: 9, lng: 9));
    await repo.addPoint('s2', 1, _fix(lat: 9.1, lng: 9.1));

    expect(await repo.pointCount('s1'), 1);
    expect(await repo.pointCount('s2'), 2);
    expect((await repo.pointsForSession('s1')).single.latitude, 1);
  });

  test('deleteForSession removes only that session\'s points', () async {
    await repo.addPoint('s1', 0, _fix(lat: 1, lng: 1));
    await repo.addPoint('s2', 0, _fix(lat: 9, lng: 9));

    await repo.deleteForSession('s1');

    expect(await repo.pointsForSession('s1'), isEmpty);
    expect(await repo.pointsForSession('s2'), hasLength(1));
  });

  group('deleteOlderThan (C4a.6\'s 90-day maintenance job)', () {
    test('removes only points recorded before the cutoff, across every session', () async {
      final cutoff = DateTime.utc(2026, 8, 1);
      await repo.addPoint('s1', 0, _fix(lat: 1, lng: 1, recordedAt: DateTime.utc(2026, 7, 1)));
      await repo.addPoint('s1', 1, _fix(lat: 2, lng: 2, recordedAt: DateTime.utc(2026, 8, 15)));
      await repo.addPoint('s2', 0, _fix(lat: 3, lng: 3, recordedAt: DateTime.utc(2026, 6, 1)));

      final deleted = await repo.deleteOlderThan(cutoff);

      expect(deleted, 2);
      expect(await repo.pointsForSession('s1'), hasLength(1));
      // Drift round-trips DateTime columns as local-zone instants — same
      // moment, different `isUtc` flag, so `==` (which also compares that
      // flag, per DateTime's own docs) would spuriously fail here.
      final remaining = (await repo.pointsForSession('s1')).single.recordedAt;
      expect(remaining.isAtSameMomentAs(DateTime.utc(2026, 8, 15)), isTrue);
      expect(await repo.pointsForSession('s2'), isEmpty);
    });

    test('a point exactly at the cutoff is kept, not deleted', () async {
      final cutoff = DateTime.utc(2026, 8, 1);
      await repo.addPoint('s1', 0, _fix(lat: 1, lng: 1, recordedAt: cutoff));

      await repo.deleteOlderThan(cutoff);

      expect(await repo.pointsForSession('s1'), hasLength(1));
    });
  });

  group('cascade delete from WorkoutSessionRepository.delete()', () {
    test('a never-synced session\'s track points are wiped immediately alongside it', () async {
      final sessionRepo =
          WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
      final clientId = await sessionRepo.create(
        startedAt: DateTime.utc(2026, 8, 12, 7),
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
      );
      await repo.addPoint(clientId, 0, _fix(lat: 47.5, lng: 19.05));
      await repo.addPoint(clientId, 1, _fix(lat: 47.501, lng: 19.051));
      expect(await repo.pointCount(clientId), 2);

      await sessionRepo.delete(clientId);

      expect(await repo.pointCount(clientId), 0);
    });
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/features/workouts/application/track_point_maintenance.dart';
import 'package:lifey/features/workouts/data/cardio_track_point_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// docs/cardio/54-cardio-gps-route-plan.md §5 point 5, C4a.6 — the 90-day
/// raw-point retention job, gated to run at most once a day (see the class
/// doc for why: this is meant to be called from every sync trigger,
/// including a 60 s timer).

void main() {
  late AppDatabase db;
  late CardioTrackPointRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    repo = CardioTrackPointRepository(db);
  });

  tearDown(() => db.close());

  test('prunes points older than 90 days on first run', () async {
    final now = DateTime.now();
    await repo.addPoint(
      's1',
      0,
      LocationFix(latitude: 1, longitude: 1, recordedAt: now.subtract(const Duration(days: 91))),
    );
    await repo.addPoint(
      's1',
      1,
      LocationFix(latitude: 2, longitude: 2, recordedAt: now.subtract(const Duration(days: 10))),
    );

    await TrackPointMaintenance(repo).runIfDue();

    final remaining = await repo.pointsForSession('s1');
    expect(remaining, hasLength(1));
    expect(remaining.single.latitude, 2);
  });

  test('a second call within the same day is a no-op, even with new stale points', () async {
    final now = DateTime.now();
    final maintenance = TrackPointMaintenance(repo);
    await maintenance.runIfDue();

    // Added only after the first run — the second call must not see it,
    // since the daily gate should skip the scan entirely.
    await repo.addPoint(
      's1',
      0,
      LocationFix(latitude: 1, longitude: 1, recordedAt: now.subtract(const Duration(days: 200))),
    );
    await maintenance.runIfDue();

    expect(await repo.pointsForSession('s1'), hasLength(1));
  });

  test('runs again once at least a day has passed since the last run', () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'cardio.trackPointMaintenance.lastRunAtEpochMs':
          now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
    });
    await repo.addPoint(
      's1',
      0,
      LocationFix(latitude: 1, longitude: 1, recordedAt: now.subtract(const Duration(days: 200))),
    );

    await TrackPointMaintenance(repo).runIfDue();

    expect(await repo.pointsForSession('s1'), isEmpty);
  });
}

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';
import 'package:lifey/features/workouts/domain/waypoint_track_match.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// docs/cardio/60 C8.4 — a waypoint carries only where it was marked
/// (lat/lng/altitude); the summary screen derives its distance/elapsed-time
/// by matching it against the session's own local track, the same source
/// the elevation profile (C8.3) reads from.

/// Meters per degree of latitude *as [haversineMeters] computes it* — see
/// `elevation_profile_test.dart`'s identical fixture note.
final double _metersPerDegreeLat = 6371000 * math.pi / 180;

/// A straight-line-north trail, 5 m apart, one point per second, climbing at
/// [altitudePerMeter] m per horizontal meter.
List<TrackFilterTrailPoint> _straightTrail({
  required int steps,
  double altitudePerMeter = 0,
  DateTime? start,
}) {
  final t0 = start ?? DateTime.utc(2026, 8, 19, 7, 0, 0);
  return [
    for (var i = 0; i <= steps; i++)
      TrackFilterTrailPoint(
        latitude: 47.5 + (i * 5) / _metersPerDegreeLat,
        longitude: 19.05,
        altitude: (i * 5) * altitudePerMeter,
        recordedAt: t0.add(Duration(seconds: i)),
      ),
  ];
}

void main() {
  group('matchWaypointsToTrail', () {
    test('empty waypoints returns empty regardless of trail', () {
      expect(matchWaypointsToTrail(const [], _straightTrail(steps: 10)), isEmpty);
    });

    test('empty trail falls back to the waypoint\'s own stored altitude, null distance/elapsed',
        () {
      const waypoint =
          CardioWaypoint(waypointIndex: 0, latitude: 47.5, longitude: 19.05, altitudeMeters: 612);

      final matched = matchWaypointsToTrail([waypoint], const []);

      expect(matched, hasLength(1));
      expect(matched.single.distanceMeters, isNull);
      expect(matched.single.elapsedSeconds, isNull);
      expect(matched.single.altitudeMeters, 612);
    });

    test('a waypoint marked exactly at a trail point matches its distance/elapsed/altitude', () {
      final trail = _straightTrail(steps: 20, altitudePerMeter: 0.1); // 0.5 m climb per point
      // Trail point 10 sits 50 m in, at t=10s, altitude 5 m.
      final waypoint = CardioWaypoint(
        waypointIndex: 0,
        latitude: trail[10].latitude,
        longitude: trail[10].longitude,
      );

      final matched = matchWaypointsToTrail([waypoint], trail).single;

      expect(matched.distanceMeters, closeTo(50, 0.5));
      expect(matched.elapsedSeconds, 10);
      expect(matched.altitudeMeters, closeTo(5, 0.5));
    });

    test('a waypoint marked slightly off-trail snaps to the nearest point, not an interpolation',
        () {
      final trail = _straightTrail(steps: 20);
      // A few metres east of trail point 4 (20 m in) — nearer to it than to
      // point 3 or point 5.
      final waypoint =
          CardioWaypoint(waypointIndex: 0, latitude: trail[4].latitude, longitude: 19.0501);

      final matched = matchWaypointsToTrail([waypoint], trail).single;

      expect(matched.distanceMeters, closeTo(20, 0.5));
      expect(matched.elapsedSeconds, 4);
    });

    test('an out-and-back route matches the geographically nearest point, not the last one', () {
      // Out to 100 m, then straight back — point 30 (outbound) and point 30
      // seconds later on the way back (recorded index 30) sit at nearly the
      // same spot; a waypoint marked there should match by proximity, not by
      // scanning order (both existing implementations would tie on index
      // order, so this pins the "nearest wins" contract explicitly).
      final outbound = _straightTrail(steps: 20);
      final t1 = outbound.last.recordedAt;
      final inbound = [
        for (var i = 1; i <= 20; i++)
          TrackFilterTrailPoint(
            latitude: 47.5 + ((20 - i) * 5) / _metersPerDegreeLat,
            longitude: 19.05,
            altitude: 0,
            recordedAt: t1.add(Duration(seconds: i)),
          ),
      ];
      final trail = [...outbound, ...inbound];
      // Marked right at the turnaround point (index 20, 100 m in, t=20s).
      final waypoint = CardioWaypoint(
        waypointIndex: 0,
        latitude: trail[20].latitude,
        longitude: trail[20].longitude,
      );

      final matched = matchWaypointsToTrail([waypoint], trail).single;

      expect(matched.distanceMeters, closeTo(100, 0.5));
      expect(matched.elapsedSeconds, 20);
    });

    test('results come back in waypointIndex order regardless of input order', () {
      final trail = _straightTrail(steps: 20);
      final first = CardioWaypoint(
          waypointIndex: 0, latitude: trail[2].latitude, longitude: trail[2].longitude);
      final second = CardioWaypoint(
          waypointIndex: 1, latitude: trail[15].latitude, longitude: trail[15].longitude);

      final matched = matchWaypointsToTrail([second, first], trail);

      expect(matched.map((m) => m.waypoint.waypointIndex), [0, 1]);
    });

    test('the trail\'s own altitude wins over the waypoint\'s stored one when both exist', () {
      final trail = _straightTrail(steps: 10, altitudePerMeter: 0.1);
      final waypoint = CardioWaypoint(
        waypointIndex: 0,
        latitude: trail[5].latitude,
        longitude: trail[5].longitude,
        // A stale/coarser value from the moment of marking — the trail's own
        // recorded altitude at the matched point is the more precise source.
        altitudeMeters: 999,
      );

      final matched = matchWaypointsToTrail([waypoint], trail).single;

      expect(matched.altitudeMeters, closeTo(2.5, 0.1));
    });
  });
}

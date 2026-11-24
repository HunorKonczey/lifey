import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/health/health_cardio_track.dart';
import 'package:lifey/features/workouts/domain/route_encoder.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';

/// docs/integrations/89 G1.8: an imported workout's route and heart-rate zones.

/// The fixed run in test/fixtures/health/garmin_run_route.json: 202 fixes, one every 3 s, with a 90 s signal gap after the
/// second leg.
List<RouteLocation> _fixtureRoute() {
  final json = jsonDecode(File('test/fixtures/health/garmin_run_route.json').readAsStringSync()) as Map<String, dynamic>;
  return [
    for (final p in (json['locations'] as List).cast<Map<String, dynamic>>())
      RouteLocation(
        latitude: (p['lat'] as num).toDouble(),
        longitude: (p['lon'] as num).toDouble(),
        altitude: (p['alt'] as num).toDouble(),
        at: DateTime.fromMillisecondsSinceEpoch(p['t'] as int, isUtc: true),
      ),
  ];
}

void main() {
  group('routePolylineFromLocations', () {
    test('the fixture run becomes a simplified route with the gap kept as its own segment', () {
      final fixes = _fixtureRoute();
      final route = routePolylineFromLocations(fixes)!;
      final segments = decodeRouteSegments(route.polyline);

      // The 90 s signal gap splits the line, so the painter draws it dashed instead of as a straight jump.
      expect(segments, hasLength(2));
      // Douglas–Peucker keeps a fraction of a 1 fix / 3 s track.
      expect(route.pointCount, lessThan(fixes.length ~/ 2));
      expect(route.pointCount, segments.fold<int>(0, (n, s) => n + s.length));

      // The ends survive, at polyline precision (1e-5 degrees, about a meter).
      final first = segments.first.first;
      final last = segments.last.last;
      expect(haversineMeters(first.$1, first.$2, fixes.first.latitude, fixes.first.longitude), lessThan(2));
      expect(haversineMeters(last.$1, last.$2, fixes.last.latitude, fixes.last.longitude), lessThan(2));
      // The altitude channel is carried for the elevation profile.
      expect(first.$3, closeTo(fixes.first.altitude!, 0.1));
    });

    test('every original fix lies within the 5 m tolerance of the simplified line', () {
      final fixes = _fixtureRoute();
      final segments = decodeRouteSegments(routePolylineFromLocations(fixes)!.polyline);

      for (final fix in fixes) {
        final distance = segments
            .map((segment) => _distanceToLine(fix, segment))
            .reduce((a, b) => a < b ? a : b);
        // 5 m Douglas–Peucker tolerance plus the polyline's 1e-5 degree rounding.
        expect(distance, lessThan(6.5));
      }
    });

    test('fix order does not matter: the route is sorted by time', () {
      final fixes = _fixtureRoute();
      expect(routePolylineFromLocations(fixes.reversed.toList())!.polyline, routePolylineFromLocations(fixes)!.polyline);
    });

    test('no route (Health Connect without the Exercise routes permission) is null, not an error', () {
      expect(routePolylineFromLocations(const []), isNull);
    });

    test('a single fix, or fixes no GPS reports, draw nothing', () {
      final at = DateTime.utc(2026, 11, 20, 6);
      expect(routePolylineFromLocations([RouteLocation(latitude: 47.5, longitude: 19.05, at: at)]), isNull);
      expect(
        routePolylineFromLocations([
          RouteLocation(latitude: 0, longitude: 0, at: at),
          RouteLocation(latitude: 91, longitude: 19, at: at.add(const Duration(seconds: 3))),
          RouteLocation(latitude: 47.5, longitude: 19.05, at: at.add(const Duration(seconds: 6))),
        ]),
        isNull,
      );
    });
  });

  group('hrZoneSecondsFromSamples', () {
    final start = DateTime.utc(2026, 11, 20, 6);
    final end = start.add(const Duration(minutes: 10));
    // Max 190: Z1 ≤ 114, Z2 ≤ 133, Z3 ≤ 152, Z4 ≤ 171, Z5 above.
    HeartRateSample at(int second, double bpm) => HeartRateSample(start.add(Duration(seconds: second)), bpm);

    test('each sample counts until the next one, in the zone of its beat', () {
      final zones = hrZoneSecondsFromSamples(
        [
          for (var s = 0; s < 120; s += 5) at(s, 110), // Z1 for 2 min
          for (var s = 120; s < 360; s += 5) at(s, 145), // Z3 for 4 min
          for (var s = 360; s < 600; s += 5) at(s, 165), // Z4 for 4 min, the last one runs to the end
        ],
        start: start,
        end: end,
        maxHeartRate: 190,
      );

      expect(zones, [120, 0, 240, 240, 0]);
    });

    test('a silence longer than 30 s counts only 30 s, so the gap shows as unmeasured', () {
      final zones = hrZoneSecondsFromSamples(
        [at(0, 180), at(300, 180)],
        start: start,
        end: end,
        maxHeartRate: 190,
      );

      expect(zones, [0, 0, 0, 0, 60]);
    });

    test('the zones never add up to more than the session lasted', () {
      final zones = hrZoneSecondsFromSamples(
        [for (var s = 0; s <= 600; s++) at(s, 150)],
        start: start,
        end: end,
        maxHeartRate: 190,
      )!;

      expect(zones.fold<int>(0, (a, b) => a + b), lessThanOrEqualTo(600));
    });

    test('samples outside the session, or unordered, are handled', () {
      final zones = hrZoneSecondsFromSamples(
        [at(20, 120), at(-60, 190), at(0, 120), at(700, 190), at(10, 120)],
        start: start,
        end: end,
        maxHeartRate: 190,
      );

      // 0→10→20, then the last sample's 30 s cap.
      expect(zones, [0, 50, 0, 0, 0]);
    });

    test('no birth date, no samples, or no sample inside the session: no zones', () {
      expect(hrZoneSecondsFromSamples([at(0, 150)], start: start, end: end, maxHeartRate: null), isNull);
      expect(hrZoneSecondsFromSamples(const [], start: start, end: end, maxHeartRate: 190), isNull);
      expect(hrZoneSecondsFromSamples([at(900, 150)], start: start, end: end, maxHeartRate: 190), isNull);
    });
  });

  group('routeForWorkout', () {
    final start = DateTime.utc(2026, 11, 20, 6);
    final end = start.add(const Duration(minutes: 42));
    final fix = [RouteLocation(latitude: 47.5, longitude: 19.05, at: start)];
    final other = [RouteLocation(latitude: 48, longitude: 20, at: start)];

    test('Health Connect: the route naming the workout', () {
      final routes = [
        HealthWorkoutRoute(workoutUuid: 'hc-other', start: start, end: end, locations: other),
        HealthWorkoutRoute(workoutUuid: 'hc-run-1', start: start, end: end, locations: fix),
      ];
      expect(routeForWorkout(routes, workoutUuid: 'hc-run-1', start: start, end: end), same(fix));
    });

    test('HealthKit: the unnamed route that overlaps the workout the most', () {
      final routes = [
        HealthWorkoutRoute(
          workoutUuid: null,
          start: start.subtract(const Duration(minutes: 50)),
          end: start.add(const Duration(minutes: 2)),
          locations: other,
        ),
        HealthWorkoutRoute(workoutUuid: null, start: start.add(const Duration(seconds: 5)), end: end, locations: fix),
      ];
      expect(routeForWorkout(routes, workoutUuid: 'hk-1', start: start, end: end), same(fix));
    });

    test('a route naming another workout, a consent-required empty route, or no overlap: nothing', () {
      final routes = [
        HealthWorkoutRoute(workoutUuid: 'hc-other', start: start, end: end, locations: other),
        HealthWorkoutRoute(workoutUuid: 'hc-run-1', start: start, end: end, locations: const []),
        HealthWorkoutRoute(
          workoutUuid: null,
          start: end.add(const Duration(hours: 1)),
          end: end.add(const Duration(hours: 2)),
          locations: other,
        ),
      ];
      expect(routeForWorkout(routes, workoutUuid: 'hc-run-1', start: start, end: end), isEmpty);
    });
  });
}

/// Shortest distance in meters from [fix] to the polyline [segment], in a local planar projection (fine at this scale).
double _distanceToLine(RouteLocation fix, List<(double, double, double)> segment) {
  const mPerLat = 111320.0;
  final mPerLon = mPerLat * math.cos(fix.latitude * math.pi / 180);
  (double, double) project(double lat, double lon) => ((lon - fix.longitude) * mPerLon, (lat - fix.latitude) * mPerLat);
  if (segment.length == 1) {
    final (x, y) = project(segment.single.$1, segment.single.$2);
    return math.sqrt(x * x + y * y);
  }
  var best = double.infinity;
  for (var i = 0; i + 1 < segment.length; i++) {
    final (ax, ay) = project(segment[i].$1, segment[i].$2);
    final (bx, by) = project(segment[i + 1].$1, segment[i + 1].$2);
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0 ? 0.0 : ((-ax * dx - ay * dy) / len2).clamp(0.0, 1.0);
    final px = ax + t * dx, py = ay + t * dy;
    best = math.min(best, math.sqrt(px * px + py * py));
  }
  return best;
}

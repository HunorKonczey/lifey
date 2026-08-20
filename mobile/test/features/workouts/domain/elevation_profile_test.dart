import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/elevation_profile.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';

/// docs/cardio/60 C8.3 — the real, local-track-derived elevation profile
/// (cumulative distance, not a synthetic per-second index) that replaces the
/// old polyline-based approximation. docs/cardio/54-cardio-gps-route-plan.md
/// §4.3 for the gap threshold this shares with `route_encoder.dart` and
/// `best_effort_calculator.dart`.

/// Meters per degree of latitude *as [haversineMeters] computes it* — using
/// the textbook 111320 instead leaves a ~0.1% bias in every expected value.
final double _metersPerDegreeLat = 6371000 * math.pi / 180;

/// A straight-line-north trail, [stepMeters] apart, one point per second,
/// climbing at [altitudePerMeter] m per horizontal meter — same shape
/// `cardio_splits_calculator_test.dart` uses.
List<TrackFilterTrailPoint> _straightTrail({
  required int steps,
  double stepMeters = 5,
  double altitudePerMeter = 0,
  DateTime? start,
  bool withAltitude = true,
}) {
  final t0 = start ?? DateTime.utc(2026, 8, 19, 7, 0, 0);
  return [
    for (var i = 0; i <= steps; i++)
      TrackFilterTrailPoint(
        latitude: 47.5 + (i * stepMeters) / _metersPerDegreeLat,
        longitude: 19.05,
        altitude: withAltitude ? (i * stepMeters) * altitudePerMeter : null,
        recordedAt: t0.add(Duration(seconds: i)),
      ),
  ];
}

void main() {
  group('buildElevationProfile', () {
    test('fewer than two points has no profile', () {
      expect(buildElevationProfile(const []), isNull);
      final single = [
        TrackFilterTrailPoint(
            latitude: 47.5, longitude: 19.05, recordedAt: DateTime.utc(2026, 8, 19)),
      ];
      expect(buildElevationProfile(single), isNull);
    });

    test('no altitude data anywhere in the trail has no profile', () {
      final trail = _straightTrail(steps: 100, withAltitude: false);
      expect(buildElevationProfile(trail), isNull);
    });

    test('a single gap-free trail is one segment with no gaps', () {
      final trail = _straightTrail(steps: 200, stepMeters: 5, altitudePerMeter: 0.02);

      final profile = buildElevationProfile(trail)!;

      expect(profile.segments, hasLength(1));
      expect(profile.segments.single, hasLength(201));
      expect(profile.gaps, isEmpty);
      // 200 steps * 5 m = 1000 m.
      expect(profile.totalDistanceMeters, closeTo(1000, 1));
    });

    test('cumulative distance grows monotonically along a segment', () {
      final trail = _straightTrail(steps: 100, stepMeters: 5, altitudePerMeter: 0.01);
      final profile = buildElevationProfile(trail)!;

      final distances = profile.segments.single.map((p) => p.cumulativeDistanceMeters).toList();
      for (var i = 1; i < distances.length; i++) {
        expect(distances[i], greaterThan(distances[i - 1]));
      }
      expect(distances.first, closeTo(0, 0.01));
      expect(distances.last, closeTo(500, 1));
    });

    test('elapsed time is measured from the very first point of the whole trail', () {
      final start = DateTime.utc(2026, 8, 19, 6, 0, 0);
      final trail = _straightTrail(steps: 50, stepMeters: 5, altitudePerMeter: 0.01, start: start);
      final profile = buildElevationProfile(trail)!;

      final points = profile.segments.single;
      expect(points.first.elapsedSeconds, 0);
      expect(points.last.elapsedSeconds, 50);
    });

    test('the peak is the single highest point across the whole trail', () {
      // Climbs to 10 m, then descends — the peak sits mid-trail, not at either end.
      final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
      final up = [
        for (var i = 0; i <= 100; i++)
          TrackFilterTrailPoint(
            latitude: 47.5 + (i * 5) / _metersPerDegreeLat,
            longitude: 19.05,
            altitude: i * 0.1,
            recordedAt: t0.add(Duration(seconds: i)),
          ),
      ];
      final down = [
        for (var i = 1; i <= 100; i++)
          TrackFilterTrailPoint(
            latitude: 47.5 + ((100 + i) * 5) / _metersPerDegreeLat,
            longitude: 19.05,
            altitude: 10 - i * 0.1,
            recordedAt: t0.add(Duration(seconds: 100 + i)),
          ),
      ];
      final profile = buildElevationProfile([...up, ...down])!;

      expect(profile.peak!.altitudeMeters, closeTo(10, 0.01));
      // Halfway through the 1000 m round trip, i.e. 500 m in.
      expect(profile.peak!.cumulativeDistanceMeters, closeTo(500, 5));
    });

    group('real signal gaps (§4.3)', () {
      test('a gap over the threshold splits the trail into two segments', () {
        final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
        final before = _straightTrail(steps: 50, stepMeters: 5, altitudePerMeter: 0.01, start: t0);
        // 90 s of silence, then resumes 200 m further north.
        final resumeAt = before.last.recordedAt.add(const Duration(seconds: 90));
        final after = [
          for (var i = 0; i <= 50; i++)
            TrackFilterTrailPoint(
              latitude: 47.5 + (250 + i * 5) / _metersPerDegreeLat,
              longitude: 19.05,
              altitude: 3 + i * 0.01,
              recordedAt: resumeAt.add(Duration(seconds: i)),
            ),
        ];

        final profile = buildElevationProfile([...before, ...after])!;

        expect(profile.segments, hasLength(2));
        expect(profile.gaps, hasLength(1));
      });

      test("the gap's width is the straight-line distance across it", () {
        final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
        final before = _straightTrail(steps: 10, stepMeters: 5, altitudePerMeter: 0, start: t0);
        final resumeAt = before.last.recordedAt.add(const Duration(seconds: 90));
        // Resumes 100 m further north of where the trail left off (a straight
        // hop — the same "bridge with a straight line" approximation
        // route_painter.dart's dashed bridge already draws).
        final after = [
          TrackFilterTrailPoint(
            latitude: before.last.latitude + 100 / _metersPerDegreeLat,
            longitude: 19.05,
            altitude: 1,
            recordedAt: resumeAt,
          ),
          TrackFilterTrailPoint(
            latitude: before.last.latitude + 105 / _metersPerDegreeLat,
            longitude: 19.05,
            altitude: 1,
            recordedAt: resumeAt.add(const Duration(seconds: 1)),
          ),
        ];

        final profile = buildElevationProfile([...before, ...after])!;

        expect(profile.gaps.single.widthMeters, closeTo(100, 1));
      });

      test('gaps position segments correctly along the shared distance axis', () {
        final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
        // Segment A: 0-50 m. Gap: 50-150 m (100 m straight hop). Segment B
        // starts at 150 m and continues another 50 m.
        final segA = _straightTrail(steps: 10, stepMeters: 5, altitudePerMeter: 0, start: t0);
        final resumeAt = segA.last.recordedAt.add(const Duration(seconds: 90));
        final segB = [
          for (var i = 0; i <= 10; i++)
            TrackFilterTrailPoint(
              latitude: segA.last.latitude + (100 + i * 5) / _metersPerDegreeLat,
              longitude: 19.05,
              altitude: 2,
              recordedAt: resumeAt.add(Duration(seconds: i)),
            ),
        ];

        final profile = buildElevationProfile([...segA, ...segB])!;

        expect(profile.segments[0].last.cumulativeDistanceMeters, closeTo(50, 1));
        expect(profile.gaps.single.startDistanceMeters, closeTo(50, 1));
        expect(profile.gaps.single.endDistanceMeters, closeTo(150, 1));
        expect(profile.segments[1].first.cumulativeDistanceMeters, closeTo(150, 1));
        expect(profile.totalDistanceMeters, closeTo(200, 1));
      });
    });

    test('allPoints flattens every segment in playback order — what the chart hit-tests', () {
      final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
      final segA = _straightTrail(steps: 10, stepMeters: 5, altitudePerMeter: 0, start: t0);
      final resumeAt = segA.last.recordedAt.add(const Duration(seconds: 90));
      final segB = [
        for (var i = 0; i <= 5; i++)
          TrackFilterTrailPoint(
            latitude: segA.last.latitude + (100 + i * 5) / _metersPerDegreeLat,
            longitude: 19.05,
            altitude: 2,
            recordedAt: resumeAt.add(Duration(seconds: i)),
          ),
      ];

      final profile = buildElevationProfile([...segA, ...segB])!;

      expect(profile.allPoints, hasLength(11 + 6));
      expect(profile.allPoints.first.cumulativeDistanceMeters, closeTo(0, 0.1));
      expect(profile.allPoints.last.cumulativeDistanceMeters, profile.totalDistanceMeters);
    });

    test('a point missing altitude is skipped as a vertex but its distance still counts', () {
      final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
      final trail = [
        TrackFilterTrailPoint(latitude: 47.5, longitude: 19.05, altitude: 100, recordedAt: t0),
        // No altitude on this one.
        TrackFilterTrailPoint(
            latitude: 47.5 + 5 / _metersPerDegreeLat,
            longitude: 19.05,
            recordedAt: t0.add(const Duration(seconds: 1))),
        TrackFilterTrailPoint(
            latitude: 47.5 + 10 / _metersPerDegreeLat,
            longitude: 19.05,
            altitude: 100,
            recordedAt: t0.add(const Duration(seconds: 2))),
      ];

      final profile = buildElevationProfile(trail)!;

      // Only the two altitude-bearing points become vertices...
      expect(profile.segments.single, hasLength(2));
      // ...but the middle point's 5 m still counted toward the total.
      expect(profile.totalDistanceMeters, closeTo(10, 0.5));
      expect(profile.segments.single.last.cumulativeDistanceMeters, closeTo(10, 0.5));
    });
  });
}

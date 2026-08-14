import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/cardio_splits_calculator.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';

/// docs/cardio/54-cardio-gps-route-plan.md §5 point 4 ("a splitek is ekkor
/// számolódnak, a szűrt pontokból") + docs/cardio/52-cardio-domain-backend-plan.md
/// §2.3 ("az utolsó split rövidebb").

const _metersPerDegreeLat = 111320.0;

/// A straight-line-north trail: [stepMeters] apart, one point per second,
/// altitude rising linearly at [altitudePerMeter] m of climb per meter of
/// distance — makes every split's expected distance/duration/elevation
/// delta exactly computable by hand.
List<TrackFilterTrailPoint> _straightTrail({
  required int steps,
  double stepMeters = 5,
  double altitudePerMeter = 0.01,
}) {
  final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
  return [
    for (var i = 0; i <= steps; i++)
      TrackFilterTrailPoint(
        latitude: 47.5 + (i * stepMeters) / _metersPerDegreeLat,
        longitude: 19.05,
        altitude: (i * stepMeters) * altitudePerMeter,
        recordedAt: t0.add(Duration(seconds: i)),
      ),
  ];
}

void main() {
  group('computeSplits', () {
    test('an empty trail has no splits', () {
      expect(computeSplits(const []), isEmpty);
    });

    test('a single-point trail has no splits', () {
      final trail = [
        TrackFilterTrailPoint(latitude: 47.5, longitude: 19.05, recordedAt: DateTime.utc(2026, 8, 13)),
      ];
      expect(computeSplits(trail), isEmpty);
    });

    test('a track under 1 km produces exactly one, shorter split', () {
      // 600 m at 5 m/s => 120 s.
      final trail = _straightTrail(steps: 120);
      final splits = computeSplits(trail);

      expect(splits.length, 1);
      expect(splits.single.splitIndex, 0);
      expect(splits.single.distanceMeters, closeTo(600, 5));
      expect(splits.single.durationSeconds, closeTo(120, 1));
      expect(splits.single.elevationDeltaM, closeTo(6, 0.2)); // 600 m * 0.01 m/m
    });

    test('a 2.5 km track produces two full 1 km splits and one 500 m remainder', () {
      // 2500 m at 5 m/s => 500 s.
      final trail = _straightTrail(steps: 500);
      final splits = computeSplits(trail);

      expect(splits.length, 3);

      expect(splits[0].splitIndex, 0);
      expect(splits[0].distanceMeters, 1000);
      expect(splits[0].durationSeconds, closeTo(200, 1));
      expect(splits[0].elevationDeltaM, closeTo(10, 0.2));

      expect(splits[1].splitIndex, 1);
      expect(splits[1].distanceMeters, 1000);
      expect(splits[1].durationSeconds, closeTo(200, 1));
      expect(splits[1].elevationDeltaM, closeTo(10, 0.2));

      expect(splits[2].splitIndex, 2);
      expect(splits[2].distanceMeters, closeTo(500, 5));
      expect(splits[2].durationSeconds, closeTo(100, 1));
      expect(splits[2].elevationDeltaM, closeTo(5, 0.2));
    });

    test('avgHeartRate is always null — no per-point HR source yet', () {
      final trail = _straightTrail(steps: 120);
      expect(computeSplits(trail).every((s) => s.avgHeartRate == null), isTrue);
    });

    test('a trail with no altitude data at all yields null elevation deltas, not zero', () {
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      final trail = [
        for (var i = 0; i <= 120; i++)
          TrackFilterTrailPoint(
            latitude: 47.5 + (i * 5) / _metersPerDegreeLat,
            longitude: 19.05,
            recordedAt: t0.add(Duration(seconds: i)),
          ),
      ];
      final splits = computeSplits(trail);
      expect(splits.single.elevationDeltaM, isNull);
    });
  });
}

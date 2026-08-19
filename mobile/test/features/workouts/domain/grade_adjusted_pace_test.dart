import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/grade_adjusted_pace.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';

/// docs/cardio/60 C8.2 — kész-ha: "Sík terepen a GAP megegyezik a nyers
/// tempóval" (tested below, exactly), and the formula itself
/// (docs/cardio/56-cardio-statistics-plan.md D-C3.9, Minetti et al. 2002).

const _metersPerDegreeLat = 111320.0;

/// A straight-line-north trail, [stepMeters] apart, one point per second,
/// with a constant grade (climb per horizontal meter) — the same shape
/// `cardio_splits_calculator_test.dart` uses, so every expected number here
/// is exactly computable by hand.
List<TrackFilterTrailPoint> _straightTrail({
  required int steps,
  double stepMeters = 5,
  double grade = 0,
  bool withAltitude = true,
}) {
  final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
  return [
    for (var i = 0; i <= steps; i++)
      TrackFilterTrailPoint(
        latitude: 47.5 + (i * stepMeters) / _metersPerDegreeLat,
        longitude: 19.05,
        altitude: withAltitude ? (i * stepMeters) * grade : null,
        recordedAt: t0.add(Duration(seconds: i)),
      ),
  ];
}

double _rawPaceSecondsPerKm(List<TrackFilterTrailPoint> trail) {
  final first = trail.first;
  final last = trail.last;
  final distance = haversineMeters(first.latitude, first.longitude, last.latitude, last.longitude);
  final seconds = last.recordedAt.difference(first.recordedAt).inSeconds;
  return seconds * 1000 / distance;
}

void main() {
  group('computeGradeAdjustedPaceSecondsPerKm', () {
    test('an empty trail has no GAP', () {
      expect(computeGradeAdjustedPaceSecondsPerKm(const []), isNull);
    });

    test('a single-point trail has no GAP', () {
      final trail = [
        TrackFilterTrailPoint(latitude: 47.5, longitude: 19.05, recordedAt: DateTime.utc(2026, 8, 19)),
      ];
      expect(computeGradeAdjustedPaceSecondsPerKm(trail), isNull);
    });

    test('flat terrain: GAP equals the raw average pace exactly (the kész-ha)', () {
      // 1000 m at 4 m/s = 250 s => 250 s/km raw pace, and C(0)/C(0) = 1
      // everywhere, so the flat-equivalent distance is just the real one.
      final trail = _straightTrail(steps: 250, stepMeters: 4, grade: 0);

      final gap = computeGradeAdjustedPaceSecondsPerKm(trail)!;
      final raw = _rawPaceSecondsPerKm(trail);

      expect(gap, closeTo(raw, 0.5));
      expect(gap, closeTo(250, 1));
    });

    test('a session with no altitude data at all still reduces to the raw pace', () {
      // Every segment falls back to grade 0 with no altitude, same as the
      // explicitly-flat case above — a treadmill or an altitude-less GPS log
      // shouldn't read as "can't compute a GAP" when the terrain math itself
      // still resolves to flat.
      final trail = _straightTrail(steps: 200, stepMeters: 5, withAltitude: false);

      final gap = computeGradeAdjustedPaceSecondsPerKm(trail)!;
      final raw = _rawPaceSecondsPerKm(trail);

      expect(gap, closeTo(raw, 0.5));
    });

    test('uphill: GAP reads faster than the raw pace, crediting the climb', () {
      // A steady 8% climb costs more per horizontal meter than flat
      // (Minetti's C(i) > C(0)), so the same metabolic effort would carry
      // you *faster* on flat ground — GAP is the flat-ground speed that
      // effort buys, so it comes out as a *smaller* seconds/km than the raw
      // GPS pace. This is the "credit the climb" half of GAP (docs/cardio/56
      // D-C3.9): a slow uphill pace can still show a fast GAP.
      final trail = _straightTrail(steps: 250, stepMeters: 4, grade: 0.08);

      final gap = computeGradeAdjustedPaceSecondsPerKm(trail)!;
      final raw = _rawPaceSecondsPerKm(trail);

      expect(gap, lessThan(raw));
    });

    test('downhill: GAP reads slower than the raw pace, discounting the free speed', () {
      // A gentle descent costs less per horizontal meter than flat, so the
      // GPS pace overstates the effort actually spent — GAP corrects for
      // that "free" downhill speed by reading slower than what was measured.
      final trail = _straightTrail(steps: 250, stepMeters: 4, grade: -0.05);

      final gap = computeGradeAdjustedPaceSecondsPerKm(trail)!;
      final raw = _rawPaceSecondsPerKm(trail);

      expect(gap, greaterThan(raw));
    });

    test('the U-shape: the discount peaks around -20%, not at the steepest descent', () {
      // A naive "steeper downhill is always cheaper" model would predict the
      // GAP slowdown growing monotonically with steepness. The real Minetti
      // curve bottoms out around -20% and climbs back up toward -45%
      // (braking/eccentric work costs) — so -20%'s slowdown must be the
      // *largest* of the three, not just the largest so far.
      final mild = _straightTrail(steps: 250, stepMeters: 4, grade: -0.05);
      final minimum = _straightTrail(steps: 250, stepMeters: 4, grade: -0.20);
      final steep = _straightTrail(steps: 250, stepMeters: 4, grade: -0.40);

      final raw = _rawPaceSecondsPerKm(mild); // identical GPS pace on all three
      final mildGap = computeGradeAdjustedPaceSecondsPerKm(mild)!;
      final minimumGap = computeGradeAdjustedPaceSecondsPerKm(minimum)!;
      final steepGap = computeGradeAdjustedPaceSecondsPerKm(steep)!;

      final mildSlowdown = mildGap - raw;
      final minimumSlowdown = minimumGap - raw;
      final steepSlowdown = steepGap - raw;

      expect(minimumSlowdown, greaterThan(mildSlowdown));
      expect(minimumSlowdown, greaterThan(steepSlowdown));
      // Steep enough (-40%) that the curve has climbed most of the way back
      // toward flat cost: its GAP sits close to the raw pace again, unlike
      // the -20% minimum.
      expect(steepGap, closeTo(raw, 5));
    });

    test('a segment missing altitude at either end falls back to flat, not dropped', () {
      final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
      final trail = [
        TrackFilterTrailPoint(
            latitude: 47.5, longitude: 19.05, altitude: 100, recordedAt: t0),
        // No altitude on this one — the segment either side of it must still
        // count its distance and time, at grade 0.
        TrackFilterTrailPoint(
            latitude: 47.5 + 4 / _metersPerDegreeLat,
            longitude: 19.05,
            recordedAt: t0.add(const Duration(seconds: 1))),
        TrackFilterTrailPoint(
            latitude: 47.5 + 8 / _metersPerDegreeLat,
            longitude: 19.05,
            altitude: 100,
            recordedAt: t0.add(const Duration(seconds: 2))),
      ];

      final gap = computeGradeAdjustedPaceSecondsPerKm(trail);

      expect(gap, isNotNull);
      // Both segments are 4 m in 1 s at grade 0 (the missing-altitude one
      // falls back to flat) — so this is just the flat case: 250 s/km.
      expect(gap, closeTo(250, 1));
    });

    test('a zero-distance segment (duplicate fix) is skipped, not divide-by-zero', () {
      final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
      final trail = [
        TrackFilterTrailPoint(latitude: 47.5, longitude: 19.05, altitude: 0, recordedAt: t0),
        // Same position again — a real duplicate fix.
        TrackFilterTrailPoint(
            latitude: 47.5, longitude: 19.05, altitude: 0, recordedAt: t0.add(const Duration(seconds: 1))),
        TrackFilterTrailPoint(
            latitude: 47.5 + 4 / _metersPerDegreeLat,
            longitude: 19.05,
            altitude: 0,
            recordedAt: t0.add(const Duration(seconds: 2))),
      ];

      final gap = computeGradeAdjustedPaceSecondsPerKm(trail);

      expect(gap, isNotNull);
      expect(gap!.isFinite, isTrue);
    });

    test('an extreme, GPS-noise grade is clamped rather than blowing up the result', () {
      // A 50 m altitude jump over 1 m of horizontal distance (5000% grade) —
      // obviously bad data, not a real slope. Clamped to ±45%, the cost stays
      // bounded instead of the polynomial extrapolating to a nonsensical
      // multiplier.
      final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
      final trail = [
        TrackFilterTrailPoint(latitude: 47.5, longitude: 19.05, altitude: 0, recordedAt: t0),
        TrackFilterTrailPoint(
            latitude: 47.5 + 1 / _metersPerDegreeLat,
            longitude: 19.05,
            altitude: 50,
            recordedAt: t0.add(const Duration(seconds: 1))),
      ];

      final gap = computeGradeAdjustedPaceSecondsPerKm(trail)!;

      expect(gap.isFinite, isTrue);
      expect(gap, greaterThan(0));
      // The clamp caps the cost ratio well under, say, a 20x multiplier —
      // an unclamped quintic at i=50 would be astronomically larger.
      expect(gap, lessThan(20000));
    });
  });
}

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/best_effort_calculator.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';

/// docs/cardio/60-cardio-sport-specifics-plan.md C6.2 + §9, and
/// docs/cardio/56-cardio-statistics-plan.md D-C3.8 ("a legjobb 5 km nem az
/// átlagtempóból számolt érték").

/// Meters per degree of latitude *as [haversineMeters] computes it* — using
/// the textbook 111320 instead would leave a 0.1% bias in every expected
/// value, which is the same order as the effects these tests measure.
final double _metersPerDegreeLat = 6371000 * math.pi / 180;

/// One stretch of a run: [meters] covered in [seconds], at a constant pace.
class _Leg {
  const _Leg(this.meters, this.seconds, {this.sampled = true});

  final double meters;
  final double seconds;

  /// False for a stretch that produced no fixes at all — a tunnel, a
  /// suspended app, or a paused recording the user travelled through. Only
  /// its end point lands in the trail, which is exactly what makes it a gap.
  final bool sampled;
}

/// Builds a straight-line-north trail from [legs].
///
/// Sampled legs are walked on a **global** [stepMeters] grid, so a fix can
/// straddle a pace change the way a real one does — a per-leg grid would
/// silently put a trail point on every boundary and hide whether the
/// calculator interpolates at all. A point is forced at the end of the last
/// leg and before every unsampled leg (the last fix before signal loss).
List<TrackFilterTrailPoint> _trail(List<_Leg> legs, {double stepMeters = 10}) {
  final t0 = DateTime.utc(2026, 8, 16, 6, 0, 0);
  final points = <TrackFilterTrailPoint>[];
  var distance = 0.0;
  var elapsed = 0.0;
  var nextSample = 0.0;

  void emit() {
    points.add(TrackFilterTrailPoint(
      latitude: 47.5 + distance / _metersPerDegreeLat,
      longitude: 19.05,
      recordedAt: t0.add(Duration(milliseconds: (elapsed * 1000).round())),
    ));
  }

  emit();
  nextSample += stepMeters;

  for (var i = 0; i < legs.length; i++) {
    final leg = legs[i];
    final legStart = distance;
    final legStartElapsed = elapsed;
    final pace = leg.meters > 0 ? leg.seconds / leg.meters : 0.0;

    if (leg.sampled) {
      // A gap leg jumps the distance forward, leaving the grid cursor behind
      // it — walk it back up before sampling, or the next point lands
      // *before* the one preceding it.
      while (nextSample <= legStart) {
        nextSample += stepMeters;
      }
      while (nextSample <= legStart + leg.meters) {
        distance = nextSample;
        elapsed = legStartElapsed + (distance - legStart) * pace;
        emit();
        nextSample += stepMeters;
      }
    }

    distance = legStart + leg.meters;
    elapsed = legStartElapsed + leg.seconds;
    final nextIsGap = i + 1 < legs.length && !legs[i + 1].sampled;
    if (!leg.sampled || nextIsGap || i == legs.length - 1) {
      if (points.last.recordedAt !=
          t0.add(Duration(milliseconds: (elapsed * 1000).round()))) {
        emit();
      }
    }
  }

  return points;
}

void main() {
  group('computeBestEfforts', () {
    test('a trail-less session has no best efforts', () {
      expect(computeBestEfforts(const []).isEmpty, isTrue);
    });

    test('a single-point trail has no best efforts', () {
      final trail = [
        TrackFilterTrailPoint(
            latitude: 47.5, longitude: 19.05, recordedAt: DateTime.utc(2026, 8, 16)),
      ];
      expect(computeBestEfforts(trail).isEmpty, isTrue);
    });

    test('picks the fastest continuous km, not the average pace', () {
      // 2900 m at 6:00/km, then 1000 m at 4:00/km, then 1100 m at 6:00/km.
      // Total 5 km in 28:00 — an average of 5:36/km, which is exactly the
      // number D-C3.8 says must NOT come out as the best km.
      final efforts = computeBestEfforts(_trail(const [
        _Leg(2900, 1044),
        _Leg(1000, 240),
        _Leg(1100, 396),
      ]));

      expect(efforts.best1kSeconds, closeTo(240, 2));
      expect(efforts.best5kSeconds, closeTo(1680, 3));
      expect(efforts.best10kSeconds, isNull);
    });

    test('a session shorter than the window yields null, not a scaled guess', () {
      final efforts = computeBestEfforts(_trail(const [_Leg(2000, 600)]));

      expect(efforts.best1kSeconds, closeTo(300, 2));
      expect(efforts.best5kSeconds, isNull);
      expect(efforts.best10kSeconds, isNull);
    });

    test('a sparse trail stays close to the same run sampled densely', () {
      // Fixes 150 m apart — still under the 60 s gap threshold at this pace
      // (54 s), so this is a sparse trail and not a string of gaps. The fast
      // stretch starts mid-segment, so only interpolation can find it: a
      // search restricted to trail points would report 246 s or 252 s. Some
      // smearing is unavoidable (a segment straddling a pace change is
      // assumed to be run at one constant speed), hence closeness rather
      // than equality — but the answer must be the fast km, not the 336 s
      // average.
      const legs = [_Leg(2900, 1044), _Leg(1000, 240), _Leg(1100, 396)];

      final sparse = computeBestEfforts(_trail(legs, stepMeters: 150));

      expect(sparse.best1kSeconds, closeTo(240, 15));
      expect(sparse.best5kSeconds, closeTo(1680, 5));
      // The teeth of this test: 246 s is the best window that begins on an
      // actual trail point, so anything at or above it means the boundary
      // was snapped to a point instead of interpolated.
      expect(sparse.best1kSeconds, lessThan(246));
    });

    test('a stop in the trail costs the window its real time', () {
      // A standing runner emits no accepted fixes (the displacement gate), so
      // a 45 s traffic light is a hole in the trail, not a stretch of it. The
      // only 1 km here contains that hole: 5:00 of running + 0:45 standing.
      // Dropping the stop would report a 5:00 km that never happened.
      final efforts = computeBestEfforts(_trail(const [
        _Leg(100, 30),
        _Leg(0, 45, sampled: false),
        _Leg(900, 270),
      ]));

      expect(efforts.best1kSeconds, closeTo(345, 2));
    });

    test('a window may not span a GPS gap', () {
      // The failure docs/cardio/60 §9 is about: the user pauses at 1 km,
      // travels 5 km in 10 minutes, and resumes. Bridging that jump would
      // hand them a "best 5 km" of 10:00 — a record no runner can ever beat,
      // sitting in the PR list forever. Each gap-free piece is only 1 km, so
      // the honest answer is: no 5 km happened here.
      final efforts = computeBestEfforts(_trail(const [
        _Leg(1000, 300),
        _Leg(5000, 600, sampled: false),
        _Leg(1000, 300),
      ]));

      expect(efforts.best1kSeconds, closeTo(300, 2));
      expect(efforts.best5kSeconds, isNull);
      expect(efforts.best10kSeconds, isNull);
    });

    test('a sub-threshold pause is not a gap and still counts', () {
      // 45 s < the 60 s gap threshold, so the trail is one piece — the run
      // above and this one differ only in whether the hole is long enough to
      // cut the trail.
      final efforts = computeBestEfforts(_trail(const [
        _Leg(2500, 750),
        _Leg(0, 45, sampled: false),
        _Leg(2500, 750),
      ]));

      expect(efforts.best5kSeconds, closeTo(1545, 3));
    });

    test('the longer window is never faster per km than the shorter one', () {
      // The structural invariant behind V69's CHECK: the fastest 10 km
      // contains a 1 km that is at least as fast, so its per-km pace can
      // never beat the best 1 km — and the absolute times can only grow.
      final efforts = computeBestEfforts(_trail(const [
        _Leg(2000, 700),
        _Leg(1000, 240),
        _Leg(3000, 1200),
        _Leg(1000, 250),
        _Leg(5000, 1800),
      ]));

      final best1k = efforts.best1kSeconds!;
      final best5k = efforts.best5kSeconds!;
      final best10k = efforts.best10kSeconds!;

      expect(best1k, lessThanOrEqualTo(best5k));
      expect(best5k, lessThanOrEqualTo(best10k));
      expect(best5k / 5, greaterThanOrEqualTo(best1k.toDouble()));
      expect(best10k / 10, greaterThanOrEqualTo(best1k.toDouble()));
    });

    test('a window exactly as long as the session is still found', () {
      final efforts = computeBestEfforts(_trail(const [_Leg(1000, 279)]));

      expect(efforts.best1kSeconds, closeTo(279, 1));
      expect(efforts.best5kSeconds, isNull);
    });
  });
}

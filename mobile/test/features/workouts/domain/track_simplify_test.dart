import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';
import 'package:lifey/features/workouts/domain/track_simplify.dart';

/// docs/cardio/54-cardio-gps-route-plan.md §5 point 1 — Douglas-Peucker,
/// "~5 m tűrés", "jellemzően a pontok 10-20%-a marad, a rajz szemre azonos".

TrackFilterTrailPoint _p(double lat, double lng) {
  return TrackFilterTrailPoint(
    latitude: lat,
    longitude: lng,
    recordedAt: DateTime.utc(2026, 8, 13, 7, 0),
  );
}

const _metersPerDegreeLat = 111320.0;

void main() {
  group('simplifyTrail', () {
    test('fewer than 3 points passes through unchanged', () {
      final points = [_p(47.5, 19.05), _p(47.501, 19.05)];
      expect(simplifyTrail(points), same(points));
    });

    test('empty input passes through unchanged', () {
      expect(simplifyTrail(const []), isEmpty);
    });

    test('many collinear points on a straight line simplify to just the two endpoints', () {
      final points = [
        for (var i = 0; i <= 20; i++) _p(47.5 + i * (10 / _metersPerDegreeLat), 19.05),
      ];
      final simplified = simplifyTrail(points, toleranceMeters: 5);

      expect(simplified.length, 2);
      expect(simplified.first, same(points.first));
      expect(simplified.last, same(points.last));
    });

    test('a genuine corner far past tolerance survives; collinear points on each leg are dropped', () {
      // A -> corner: due east ~76 m in 10 steps (all collinear).
      const cornerLng = 19.05 + (10 * 7.6) / _metersPerDegreeLat;
      final eastLeg = [
        for (var i = 0; i <= 10; i++) _p(47.5, 19.05 + i * (7.6 / _metersPerDegreeLat)),
      ];
      // corner -> C: due north ~111 m in 10 steps (all collinear, different
      // direction from the east leg — the corner itself is a real bend). Same
      // longitude as the east leg's last point (`cornerLng`) — otherwise this
      // wouldn't be an L-shape but a diagonal jump.
      final northLeg = [
        for (var i = 1; i <= 10; i++) _p(47.5 + i * (11.1 / _metersPerDegreeLat), cornerLng),
      ];
      final points = [...eastLeg, ...northLeg];

      final simplified = simplifyTrail(points, toleranceMeters: 5);

      // Endpoints + the corner — nothing else, since both legs are each
      // individually straight.
      expect(simplified.length, 3);
      expect(simplified.first, same(points.first));
      expect(simplified.last, same(points.last));
      expect(simplified[1], same(eastLeg.last)); // the corner point
    });

    test('a small wobble under tolerance does not survive', () {
      // A near-straight line where the middle point is nudged ~1 m off —
      // well under the 5 m default tolerance.
      final points = [
        _p(47.5, 19.05),
        _p(47.5 + (1 / _metersPerDegreeLat), 19.05 + (5 / _metersPerDegreeLat)),
        _p(47.5, 19.05 + (10 / _metersPerDegreeLat)),
      ];
      final simplified = simplifyTrail(points, toleranceMeters: 5);
      expect(simplified.length, 2);
    });
  });
}

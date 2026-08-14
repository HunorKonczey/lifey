import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/polyline_codec.dart';

/// Google's encoded polyline algorithm format (docs/cardio/
/// 54-cardio-gps-route-plan.md §5 point 2) — delta + zigzag + 5-bit chunks
/// offset by 63. The single-value hand cases below are derived directly
/// from the spec's own arithmetic (not copied from an external example), so
/// they double-check the implementation against independently-worked-out
/// expected output, not just its own round-trip.
void main() {
  group('encodePolyline / decodePolyline — hand-derived single-value cases', () {
    test('a (0,0) point has zero deltas both ways: two "?" chars', () {
      expect(encodePolyline(const [(0.0, 0.0)]), '??');
    });

    test('a small positive latitude delta (0.00001) encodes as one non-continuation char', () {
      // latE = round(0.00001 * 1e5) = 1; zigzag(1) = 1 << 1 = 2; char = 2 + 63 = 65 ('A').
      expect(encodePolyline(const [(0.00001, 0.0)]), 'A?');
    });

    test('a small negative latitude delta (-0.00001) encodes as one non-continuation char', () {
      // latE = -1; zigzag(-1) = ~(-1 << 1) = ~(-2) = 1; char = 1 + 63 = 64 ('@').
      expect(encodePolyline(const [(-0.00001, 0.0)]), '@?');
    });
  });

  group('encodePolyline / decodePolyline — round trip', () {
    test('a multi-point track round-trips within 1e-5 degree precision', () {
      const points = [
        (47.497913, 19.040236),
        (47.498500, 19.041000),
        (47.499123, 19.039871),
        (47.500000, 19.050000),
        (46.900000, 18.500000),
      ];
      final encoded = encodePolyline(points);
      final decoded = decodePolyline(encoded);

      expect(decoded.length, points.length);
      for (var i = 0; i < points.length; i++) {
        expect(decoded[i].$1, closeTo(points[i].$1, 1e-5));
        expect(decoded[i].$2, closeTo(points[i].$2, 1e-5));
      }
    });

    test('an empty point list encodes to an empty string', () {
      expect(encodePolyline(const []), '');
      expect(decodePolyline(''), isEmpty);
    });

    test('only the alphabet\'s printable ASCII range (63-126) is ever produced', () {
      const points = [(47.5, 19.05), (-33.86, 151.2), (0.0, 0.0), (89.9999, -179.9999)];
      final encoded = encodePolyline(points);
      for (final code in encoded.codeUnits) {
        expect(code, inInclusiveRange(63, 126));
      }
    });
  });

  group('encodePolyline3 / decodePolyline3 — round trip with altitude', () {
    test('a track with altitude round-trips within precision (1e-5 deg, 0.1 m)', () {
      const points = [
        (47.497913, 19.040236, 112.3),
        (47.498500, 19.041000, 118.9),
        (47.499123, 19.039871, 115.0),
        (47.500000, 19.050000, 250.7),
      ];
      final encoded = encodePolyline3(points);
      final decoded = decodePolyline3(encoded);

      expect(decoded.length, points.length);
      for (var i = 0; i < points.length; i++) {
        expect(decoded[i].$1, closeTo(points[i].$1, 1e-5));
        expect(decoded[i].$2, closeTo(points[i].$2, 1e-5));
        expect(decoded[i].$3, closeTo(points[i].$3, 0.1));
      }
    });

    test('a negative altitude (below sea level) round-trips too', () {
      const points = [(52.0, 4.5, -3.2)];
      final decoded = decodePolyline3(encodePolyline3(points));
      expect(decoded.single.$3, closeTo(-3.2, 0.1));
    });

    test('never produces the ";" segment delimiter — safe to join with it', () {
      const points = [(47.5, 19.05, 112.3), (47.6, 19.10, 340.8), (-10.0, 170.0, 0.0)];
      final encoded = encodePolyline3(points);
      expect(encoded.contains(';'), isFalse);
    });
  });
}

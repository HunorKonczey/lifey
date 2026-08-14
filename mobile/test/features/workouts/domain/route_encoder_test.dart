import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/route_encoder.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';

/// docs/cardio/54-cardio-gps-route-plan.md §5 (closing pipeline) + §4.3/§6.1
/// (signal-gap segments) + D-C4.2 (durable altitude) — C4a.6's glue layer.

TrackFilterTrailPoint _p(double lat, double lng, DateTime at, {double? altitude}) {
  return TrackFilterTrailPoint(latitude: lat, longitude: lng, altitude: altitude, recordedAt: at);
}

void main() {
  final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);

  group('encodeRoute / decodeRouteSegments', () {
    test('an empty trail encodes to an empty string and zero points', () {
      final encoded = encodeRoute(const []);
      expect(encoded.polyline, '');
      expect(encoded.pointCount, 0);
      expect(decodeRouteSegments(''), isEmpty);
    });

    test('a continuous trail (no gap) encodes as a single segment', () {
      final trail = [
        for (var i = 0; i < 5; i++) _p(47.5 + i * 0.0001, 19.05, t0.add(Duration(seconds: i * 5)))
      ];
      final encoded = encodeRoute(trail, simplifyToleranceMeters: 0);
      final segments = decodeRouteSegments(encoded.polyline);

      expect(segments.length, 1);
      expect(encoded.polyline.contains(';'), isFalse);
    });

    test('a gap over the 60s threshold splits into two segments', () {
      final trail = [
        _p(47.5, 19.05, t0),
        _p(47.5001, 19.05, t0.add(const Duration(seconds: 10))),
        // > 60 s jump — a real signal loss.
        _p(47.6, 19.05, t0.add(const Duration(seconds: 200))),
        _p(47.6001, 19.05, t0.add(const Duration(seconds: 210))),
      ];
      final encoded = encodeRoute(trail, simplifyToleranceMeters: 0);
      final segments = decodeRouteSegments(encoded.polyline);

      expect(segments.length, 2);
      expect(segments[0].length, 2);
      expect(segments[1].length, 2);
      expect(encoded.polyline.contains(';'), isTrue);
    });

    test('a gap exactly at the threshold does not split (strictly greater-than)', () {
      final trail = [
        _p(47.5, 19.05, t0),
        _p(47.5001, 19.05, t0.add(const Duration(seconds: 60))),
      ];
      final encoded = encodeRoute(trail, simplifyToleranceMeters: 0);
      expect(decodeRouteSegments(encoded.polyline).length, 1);
    });

    test('pointCount matches the total decoded point count across all segments', () {
      final trail = [
        _p(47.5, 19.05, t0),
        _p(47.5001, 19.05, t0.add(const Duration(seconds: 10))),
        _p(47.6, 19.05, t0.add(const Duration(seconds: 200))),
      ];
      final encoded = encodeRoute(trail, simplifyToleranceMeters: 0);
      final totalDecoded =
          decodeRouteSegments(encoded.polyline).fold<int>(0, (sum, seg) => sum + seg.length);
      expect(encoded.pointCount, totalDecoded);
    });

    test('endpoints of each segment survive simplification and round-trip within precision', () {
      // A long, nearly-straight, densely-sampled segment — simplification
      // (5 m default tolerance) should thin it out, but Douglas-Peucker
      // always keeps the first/last point of whatever it's given.
      final trail = [
        for (var i = 0; i <= 50; i++) _p(47.5 + i * 0.00001, 19.05, t0.add(Duration(seconds: i)), altitude: 100 + i * 0.1)
      ];
      final encoded = encodeRoute(trail);
      final segment = decodeRouteSegments(encoded.polyline).single;

      expect(encoded.pointCount, lessThan(trail.length)); // actually simplified
      expect(segment.first.$1, closeTo(trail.first.latitude, 1e-5));
      expect(segment.first.$2, closeTo(trail.first.longitude, 1e-5));
      expect(segment.last.$1, closeTo(trail.last.latitude, 1e-5));
      expect(segment.last.$2, closeTo(trail.last.longitude, 1e-5));
      expect(segment.last.$3, closeTo(trail.last.altitude!, 0.1));
    });

    test('a missing altitude is carried through as 0, not left to crash', () {
      final trail = [_p(47.5, 19.05, t0), _p(47.5001, 19.05, t0.add(const Duration(seconds: 5)))];
      final encoded = encodeRoute(trail, simplifyToleranceMeters: 0);
      final segment = decodeRouteSegments(encoded.polyline).single;
      expect(segment.every((p) => p.$3 == 0), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';

/// docs/cardio/54-cardio-gps-route-plan.md §4.2, C4a.4 — kész-ha: "Rögzített
/// minta-nyomvonalakon a táv ≤ 5% hibával". Each gate is also tested in
/// isolation, since the §4.2 order (accuracy → speed → displacement →
/// altitude smoothing → haversine) is exactly what makes the combined
/// sample-track test trustworthy rather than coincidentally close.

LocationFix _fix({
  required double lat,
  required double lng,
  double? altitude,
  double? accuracy,
  DateTime? recordedAt,
}) {
  return LocationFix(
    latitude: lat,
    longitude: lng,
    altitude: altitude,
    accuracy: accuracy,
    recordedAt: recordedAt ?? DateTime.utc(2026, 8, 13, 7, 0),
  );
}

/// 1 degree of latitude is ~111,320 m — used to build fixture points at
/// exact, known meter offsets without depending on [haversineMeters] itself
/// (that would make the test circular).
const _metersPerDegreeLat = 111320.0;

void main() {
  group('trackFilterProfileFor', () {
    test('WALKING: 20 m accuracy, 8 km/h speed ceiling', () {
      final profile = trackFilterProfileFor('WALKING');
      expect(profile.accuracyThresholdMeters, 20);
      expect(profile.maxSpeedMetersPerSecond, closeTo(2.222, 0.001));
    });

    test('HIKING: 30 m accuracy (the doc\'s explicit "erdő alatt" exception)', () {
      final profile = trackFilterProfileFor('HIKING');
      expect(profile.accuracyThresholdMeters, 30);
      expect(profile.maxSpeedMetersPerSecond, closeTo(8.333, 0.001));
    });

    test('RUNNING: 20 m accuracy, 30 km/h speed ceiling', () {
      final profile = trackFilterProfileFor('RUNNING');
      expect(profile.accuracyThresholdMeters, 20);
      expect(profile.maxSpeedMetersPerSecond, closeTo(8.333, 0.001));
    });
  });

  group('haversineMeters', () {
    test('one degree of latitude is ~111.32 km', () {
      final d = haversineMeters(0, 0, 1, 0);
      expect(d, closeTo(111320, 200));
    });

    test('the same point twice is zero', () {
      expect(haversineMeters(47.5, 19.05, 47.5, 19.05), 0);
    });
  });

  group('TrackFilterAccumulator — accuracy gate', () {
    test('a fix above the accuracy threshold is rejected: no distance, no signal update', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      acc.addFix(_fix(lat: 47.5, lng: 19.05, accuracy: 5));
      final passed = acc.addFix(_fix(
        lat: 47.501,
        lng: 19.05,
        accuracy: 25, // over RUNNING's 20 m threshold
        recordedAt: DateTime.utc(2026, 8, 13, 7, 0, 5),
      ));

      expect(passed, isFalse);
      expect(acc.distanceMeters, 0);
      expect(acc.lastSignalAt, DateTime.utc(2026, 8, 13, 7, 0)); // unchanged — first fix only
    });

    test('a fix at or under the threshold passes', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      expect(acc.addFix(_fix(lat: 47.5, lng: 19.05, accuracy: 20)), isTrue);
    });

    test('a null accuracy is never rejected — geolocator can\'t always report it', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      expect(acc.addFix(_fix(lat: 47.5, lng: 19.05)), isTrue);
    });

    test('an accuracy-passing fix updates lastSignalAt even if speed/displacement reject it', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      acc.addFix(_fix(lat: 47.5, lng: 19.05, recordedAt: DateTime.utc(2026, 8, 13, 7, 0, 0)));
      final t2 = DateTime.utc(2026, 8, 13, 7, 0, 2);
      // A wild jump — rejected by the speed gate, but still "a signal".
      acc.addFix(_fix(lat: 47.6, lng: 19.05, recordedAt: t2));

      expect(acc.lastSignalAt, t2);
      expect(acc.distanceMeters, 0);
    });
  });

  group('TrackFilterAccumulator — speed gate', () {
    test('an implausible jump is rejected and does not move the reference point', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING')); // 30 km/h ceiling
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      acc.addFix(_fix(lat: 47.5, lng: 19.05, recordedAt: t0));
      // ~1.1 km in 2 s ≈ 2000 km/h — nowhere near plausible for running.
      acc.addFix(_fix(lat: 47.51, lng: 19.05, recordedAt: t0.add(const Duration(seconds: 2))));
      expect(acc.distanceMeters, 0);

      // A normal-paced fix measured from the *original* point (not the
      // rejected jump) should still be accepted and counted in full.
      final t1 = t0.add(const Duration(seconds: 10));
      acc.addFix(_fix(lat: 47.5005, lng: 19.05, recordedAt: t1)); // ~55.6 m / 10 s = 20 km/h
      expect(acc.distanceMeters, greaterThan(50));
      expect(acc.distanceMeters, lessThan(60));
    });

    test('a plausible-speed fix is accepted', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      acc.addFix(_fix(lat: 47.5, lng: 19.05, recordedAt: t0));
      // ~11.1 m / 3 s ≈ 13.3 km/h — plausible for a run.
      acc.addFix(_fix(lat: 47.5001, lng: 19.05, recordedAt: t0.add(const Duration(seconds: 3))));
      expect(acc.distanceMeters, greaterThan(0));
    });

    test('a non-positive time gap is ignored rather than treated as infinite speed', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      acc.addFix(_fix(lat: 47.5, lng: 19.05, recordedAt: t0));
      final passed = acc.addFix(_fix(lat: 47.5001, lng: 19.05, recordedAt: t0)); // same timestamp
      expect(passed, isTrue); // still "a signal" — just not usable for distance
      expect(acc.distanceMeters, 0);
    });
  });

  group('TrackFilterAccumulator — minimum displacement gate', () {
    test('sub-3m jitter does not move the distance or the reference point', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      acc.addFix(_fix(lat: 47.5, lng: 19.05, recordedAt: t0));
      // ~1.1 m north — under the 3 m threshold.
      acc.addFix(_fix(lat: 47.50001, lng: 19.05, recordedAt: t0.add(const Duration(seconds: 1))));
      expect(acc.distanceMeters, 0);
    });

    test('several sub-threshold fixes still accumulate once total displacement clears 3 m', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      acc.addFix(_fix(lat: 47.5, lng: 19.05, recordedAt: t0));
      // Two ~1.1 m jitter steps (each individually rejected) followed by a
      // third fix whose distance *from the original point* clears 3 m — the
      // reference point never advanced, so this is judged against the
      // start, not the last jitter step.
      acc.addFix(_fix(lat: 47.50001, lng: 19.05, recordedAt: t0.add(const Duration(seconds: 1))));
      acc.addFix(_fix(lat: 47.50002, lng: 19.05, recordedAt: t0.add(const Duration(seconds: 2))));
      acc.addFix(_fix(lat: 47.50004, lng: 19.05, recordedAt: t0.add(const Duration(seconds: 3))));

      expect(acc.distanceMeters, greaterThan(3));
    });
  });

  group('TrackFilterAccumulator — altitude smoothing / elevation gain', () {
    test('a flat track (noisy but net-zero altitude) gains ~0 m — no phantom "200 m climb"', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('HIKING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      const altitudes = [100.0, 100.3, 99.8, 100.4, 99.9, 100.2, 99.7, 100.1];
      for (var i = 0; i < altitudes.length; i++) {
        acc.addFix(_fix(
          lat: 47.5 + i * 0.0001,
          lng: 19.05,
          altitude: altitudes[i],
          recordedAt: t0.add(Duration(seconds: i * 2)),
        ));
      }
      expect(acc.elevationGainMeters, lessThan(1));
    });

    test('a genuine monotonic climb over the 1 m threshold counts, minus the moving average\'s '
        'inherent start-of-window lag', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('HIKING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      // Raw climb: 100 -> 110 m over 11 points, +1 m/point. A 5-point moving
      // average of a constant-slope ramp is the same ramp shifted by
      // (window-1)/2 points — so the *smoothed* total is short by exactly
      // that much (2 m here), not the full 10 m; this is the expected
      // behavior of the algorithm, not slack in the test.
      for (var i = 0; i <= 10; i++) {
        acc.addFix(_fix(
          lat: 47.5 + i * 0.0001,
          lng: 19.05,
          altitude: 100.0 + i,
          recordedAt: t0.add(Duration(seconds: i * 2)),
        ));
      }
      expect(acc.elevationGainMeters, closeTo(8, 0.01));
    });

    test('an in-progress climb still counts even if the session ends mid-ascent', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('HIKING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      for (var i = 0; i <= 4; i++) {
        acc.addFix(_fix(
          lat: 47.5 + i * 0.0001,
          lng: 19.05,
          altitude: 100.0 + i * 2, // steady, unambiguous 2 m/point climb
          recordedAt: t0.add(Duration(seconds: i * 2)),
        ));
      }
      // Never turned downward — elevationGainMeters must still reflect the
      // pending ascent, not just whatever was already "committed".
      expect(acc.elevationGainMeters, greaterThan(1));
    });

    test('a null altitude is skipped entirely — it never joins the smoothing window', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('HIKING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      acc.addFix(_fix(lat: 47.5, lng: 19.05, altitude: 100, recordedAt: t0));
      acc.addFix(_fix(lat: 47.5001, lng: 19.05, recordedAt: t0.add(const Duration(seconds: 2)))); // no altitude
      acc.addFix(_fix(
        lat: 47.5002,
        lng: 19.05,
        altitude: 105,
        recordedAt: t0.add(const Duration(seconds: 4)),
      ));
      // The window only ever sees [100, 105] (the null-altitude fix is
      // skipped, not inserted as a gap) — average goes 100 -> 102.5, so the
      // smoothed gain is half the 5 m raw jump, not the full amount.
      expect(acc.elevationGainMeters, closeTo(2.5, 0.01));
    });
  });

  group('TrackFilterAccumulator — sample track, kész-ha: distance within 5% of the true value', () {
    test('a 500 m straight-line track with jitter, one bad-accuracy point, and one GPS jump', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      // 51 clean points, 10 m apart, running due north — true distance
      // 500 m, at 5 m/s (18 km/h, safely under RUNNING's 30 km/h ceiling).
      const stepMeters = 10.0;
      const pointCount = 51;
      final stepDegrees = stepMeters / _metersPerDegreeLat;
      var t = t0;
      var lat = 47.5;
      for (var i = 0; i < pointCount; i++) {
        acc.addFix(_fix(lat: lat, lng: 19.05, recordedAt: t));
        // Jitter: an extra sub-3m noisy point after every clean one — must
        // not inflate the total.
        acc.addFix(_fix(
          lat: lat + 0.5 / _metersPerDegreeLat,
          lng: 19.05,
          recordedAt: t.add(const Duration(milliseconds: 500)),
        ));
        lat += stepDegrees;
        t = t.add(const Duration(seconds: 2));
      }
      // One low-accuracy point — must be dropped entirely.
      acc.addFix(_fix(lat: lat + 0.01, lng: 19.05, accuracy: 999, recordedAt: t));
      // One GPS jump (1 km in 1 s) — must be rejected by the speed gate.
      acc.addFix(_fix(lat: lat + 0.01, lng: 19.05, recordedAt: t.add(const Duration(seconds: 1))));

      const trueDistance = stepMeters * (pointCount - 1); // 500 m
      final error = (acc.distanceMeters - trueDistance).abs() / trueDistance;
      expect(error, lessThanOrEqualTo(0.05));
    });
  });

  group('TrackFilterAccumulator — trail (C4a.6\'s input)', () {
    test('the first accepted fix seeds the trail', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      acc.addFix(_fix(lat: 47.5, lng: 19.05));
      expect(acc.trail, hasLength(1));
      expect(acc.trail.single.latitude, 47.5);
      expect(acc.trail.single.longitude, 19.05);
    });

    test('a fix that advances the reference point is appended to the trail', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      acc.addFix(_fix(lat: 47.5, lng: 19.05, recordedAt: t0));
      acc.addFix(_fix(lat: 47.5001, lng: 19.05, recordedAt: t0.add(const Duration(seconds: 3))));
      expect(acc.trail, hasLength(2));
    });

    test('sub-displacement jitter is not appended to the trail', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      acc.addFix(_fix(lat: 47.5, lng: 19.05, recordedAt: t0));
      // ~1.1 m north — under the 3 m displacement threshold.
      acc.addFix(_fix(lat: 47.50001, lng: 19.05, recordedAt: t0.add(const Duration(seconds: 1))));
      expect(acc.trail, hasLength(1));
    });

    test('an accuracy- or speed-rejected fix is not appended to the trail', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('RUNNING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      acc.addFix(_fix(lat: 47.5, lng: 19.05, recordedAt: t0));
      acc.addFix(_fix(lat: 47.501, lng: 19.05, accuracy: 999, recordedAt: t0.add(const Duration(seconds: 1))));
      acc.addFix(_fix(lat: 47.6, lng: 19.05, recordedAt: t0.add(const Duration(seconds: 2)))); // speed-gate jump
      expect(acc.trail, hasLength(1));
    });

    test('the trail carries altitude and recordedAt for every kept point', () {
      final acc = TrackFilterAccumulator(trackFilterProfileFor('HIKING'));
      final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);
      acc.addFix(_fix(lat: 47.5, lng: 19.05, altitude: 200, recordedAt: t0));
      expect(acc.trail.single.altitude, 200);
      expect(acc.trail.single.recordedAt, t0);
    });
  });
}

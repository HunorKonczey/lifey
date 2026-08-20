import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/hr_zone_breakdown.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// docs/cardio/60 C9.1 + §9's risk row: "A zóna-másodpercek összege > bruttó
/// idő (óra + telefon kétszer ír)". Every failure here is a wrong number on a
/// screen, not an exception — a bar wider than its track, or a session that
/// claims 112% of itself was spent in a zone.

WorkoutSession _session({
  List<int?> zones = const [null, null, null, null, null],
  int grossSeconds = 3600,
  String activityType = 'BASKETBALL',
}) {
  final startedAt = DateTime(2026, 8, 17, 19);
  return WorkoutSession(
    clientId: 'c1',
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    finishedAt: startedAt.add(Duration(seconds: grossSeconds)),
    sessionKind: 'CARDIO',
    activityType: activityType,
    movingSeconds: grossSeconds,
    cardio: CardioMetrics(
      hrZone1Seconds: zones[0],
      hrZone2Seconds: zones[1],
      hrZone3Seconds: zones[2],
      hrZone4Seconds: zones[3],
      hrZone5Seconds: zones[4],
    ),
  );
}

void main() {
  group('no data at all', () {
    test('a session with no zone columns has no breakdown', () {
      expect(HrZoneBreakdown.fromSession(_session()), isNull);
    });

    test('all-zero zone columns count as no data, not as a flat session', () {
      // The panel must disappear rather than draw five empty rows.
      expect(HrZoneBreakdown.fromSession(_session(zones: const [0, 0, 0, 0, 0])), isNull);
    });

    test('a session with no cardio block at all has no breakdown', () {
      final strength = WorkoutSession(
        clientId: 'c1',
        exercises: const [],
        sets: const [],
        startedAt: DateTime(2026, 8, 17),
        finishedAt: DateTime(2026, 8, 17, 1),
      );
      expect(HrZoneBreakdown.fromSession(strength), isNull);
    });
  });

  group('shares', () {
    test('always lists five zones, including untouched ones', () {
      final breakdown =
          HrZoneBreakdown.fromSession(_session(zones: const [null, 1800, 1800, null, null]))!;

      expect(breakdown.slices, hasLength(5));
      expect(breakdown.secondsIn(1), 0);
      expect(breakdown.secondsIn(2), 1800);
      expect(breakdown.secondsIn(4), 0);
    });

    test('fractions sum to one and none exceeds it', () {
      final breakdown =
          HrZoneBreakdown.fromSession(_session(zones: const [600, 1200, 900, 600, 300]))!;

      final sum = breakdown.slices.fold(0.0, (a, s) => a + s.fraction);
      expect(sum, closeTo(1.0, 1e-9));
      for (final slice in breakdown.slices) {
        expect(slice.fraction, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('the sum can never exceed the gross time (§9)', () {
    test('an over-long zone sum is capped and flagged', () {
      // The double-write case: 90 minutes of zones on a 60 minute session.
      final breakdown = HrZoneBreakdown.fromSession(
        _session(zones: const [1200, 1200, 1200, 1200, 600], grossSeconds: 3600),
      )!;

      expect(breakdown.exceedsGross, isTrue);
      expect(breakdown.totalSeconds, 3600, reason: 'capped at the session length');
      expect(breakdown.coverageFraction, 1.0, reason: 'never over 100%');
    });

    test('a consistent full-coverage session is not flagged', () {
      final breakdown = HrZoneBreakdown.fromSession(
        _session(zones: const [600, 1200, 900, 600, 300], grossSeconds: 3600),
      )!;

      expect(breakdown.exceedsGross, isFalse);
      expect(breakdown.coverageFraction, 1.0);
      expect(breakdown.isPartial, isFalse);
    });
  });

  group('partial coverage', () {
    test('zones covering part of the session report that share', () {
      // A watch paired half-way through: 37 of 60 minutes measured.
      final breakdown = HrZoneBreakdown.fromSession(
        _session(zones: const [600, 900, 720, null, null], grossSeconds: 3600),
      )!;

      expect(breakdown.isPartial, isTrue);
      expect(breakdown.coverageFraction, closeTo(2220 / 3600, 1e-9));
    });

    test('a couple of rounding seconds short is not called partial', () {
      final breakdown = HrZoneBreakdown.fromSession(
        _session(zones: const [1800, 1798, null, null, null], grossSeconds: 3600),
      )!;

      expect(breakdown.isPartial, isFalse);
    });

    test('an unknown gross time is treated as fully covered, not as partial', () {
      final started = DateTime(2026, 8, 17, 19);
      final noDuration = WorkoutSession(
        clientId: 'c1',
        exercises: const [],
        sets: const [],
        startedAt: started,
        sessionKind: 'CARDIO',
        activityType: 'BASKETBALL',
        cardio: const CardioMetrics(hrZone2Seconds: 900),
      );

      final breakdown = HrZoneBreakdown.fromSession(noDuration)!;
      expect(breakdown.coverageFraction, 1.0);
      expect(breakdown.isPartial, isFalse);
    });
  });

  group('the spoken verdict (M43 — colour alone is not accessible)', () {
    test('a third or more at threshold and above is a hard session', () {
      final breakdown = HrZoneBreakdown.fromSession(
        _session(zones: const [300, 600, 900, 1200, 600]),
      )!;

      expect(breakdown.hardFraction, greaterThanOrEqualTo(0.33));
      expect(breakdown.intensity, HrZoneIntensity.hard);
    });

    test('almost nothing above tempo is an easy session', () {
      final breakdown = HrZoneBreakdown.fromSession(
        _session(zones: const [1800, 1500, 240, 60, null]),
      )!;

      expect(breakdown.intensity, HrZoneIntensity.easy);
    });

    test('the band between the two is balanced', () {
      final breakdown = HrZoneBreakdown.fromSession(
        _session(zones: const [600, 1200, 1200, 500, 100]),
      )!;

      expect(breakdown.intensity, HrZoneIntensity.balanced);
    });

    test('the verdict reads the measured time, not the session length', () {
      // 10 minutes measured, all of it at maximum, on an hour-long match:
      // that is a hard *measurement*, and the panel says so next to the "17%
      // of the session" note rather than diluting it to "easy".
      final breakdown = HrZoneBreakdown.fromSession(
        _session(zones: const [null, null, null, null, 600], grossSeconds: 3600),
      )!;

      expect(breakdown.intensity, HrZoneIntensity.hard);
      expect(breakdown.isPartial, isTrue);
    });
  });
}

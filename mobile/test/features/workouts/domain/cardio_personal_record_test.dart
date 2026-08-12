import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/cardio_personal_record.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

void main() {
  final day1 = DateTime(2026, 7, 1);
  final day2 = DateTime(2026, 7, 8);
  final day3 = DateTime(2026, 7, 15);

  WorkoutSession cardioSession(
    DateTime startedAt, {
    String activityType = 'RUNNING',
    double? distanceMeters,
    int? movingSeconds,
    double? elevationGainMeters,
    bool finished = true,
  }) {
    return WorkoutSession(
      clientId: 'cardio-${startedAt.microsecondsSinceEpoch}-$activityType',
      exercises: const [],
      sets: const [],
      startedAt: startedAt,
      finishedAt: finished ? startedAt.add(const Duration(minutes: 30)) : null,
      sessionKind: 'CARDIO',
      activityType: activityType,
      movingSeconds: movingSeconds,
      cardio: (distanceMeters == null && elevationGainMeters == null)
          ? null
          : CardioMetrics(distanceMeters: distanceMeters, elevationGainMeters: elevationGainMeters),
    );
  }

  WorkoutSession strengthSession(DateTime startedAt) {
    return WorkoutSession(
      clientId: 'strength-${startedAt.microsecondsSinceEpoch}',
      exercises: const [],
      sets: const [],
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(minutes: 30)),
    );
  }

  group('CardioPrBaseline.fromSessions', () {
    test('empty history has no baseline values', () {
      final baseline = CardioPrBaseline.fromSessions(const []);
      expect(baseline.maxDistanceMeters, isNull);
      expect(baseline.maxMovingSeconds, isNull);
      expect(baseline.maxElevationGainMeters, isNull);
    });

    test('combines RUNNING/WALKING/HIKING/INDOOR_BIKE into one distance baseline', () {
      final baseline = CardioPrBaseline.fromSessions([
        cardioSession(day1, activityType: 'RUNNING', distanceMeters: 5000),
        cardioSession(day2, activityType: 'INDOOR_BIKE', distanceMeters: 12000),
        cardioSession(day3, activityType: 'WALKING', distanceMeters: 3000),
      ]);
      expect(baseline.maxDistanceMeters, 12000);
    });

    test('tracks moving time across every family, including GAME', () {
      final baseline = CardioPrBaseline.fromSessions([
        cardioSession(day1, activityType: 'RUNNING', movingSeconds: 1800),
        cardioSession(day2, activityType: 'BASKETBALL', movingSeconds: 3600),
      ]);
      expect(baseline.maxMovingSeconds, 3600);
    });

    test('elevation baseline only comes from the DISTANCE family', () {
      final baseline = CardioPrBaseline.fromSessions([
        cardioSession(day1, activityType: 'RUNNING', elevationGainMeters: 200),
        cardioSession(day2, activityType: 'INDOOR_BIKE', elevationGainMeters: 9999),
      ]);
      expect(baseline.maxElevationGainMeters, 200);
    });

    test('ignores STRENGTH sessions entirely', () {
      final baseline = CardioPrBaseline.fromSessions([strengthSession(day1)]);
      expect(baseline.maxDistanceMeters, isNull);
      expect(baseline.maxMovingSeconds, isNull);
      expect(baseline.maxElevationGainMeters, isNull);
    });

    test('ignores not-yet-finished cardio sessions', () {
      final baseline = CardioPrBaseline.fromSessions([
        cardioSession(day1, distanceMeters: 5000, finished: false),
      ]);
      expect(baseline.maxDistanceMeters, isNull);
    });
  });

  group('detectCardioPrs', () {
    test('no baseline -> no record fires for any type', () {
      final session = cardioSession(day1, distanceMeters: 5000, movingSeconds: 1800);
      expect(detectCardioPrs(CardioPrBaseline.empty, session), isEmpty);
    });

    test('strictly greater distance is a record; equal is not', () {
      const baseline = CardioPrBaseline(maxDistanceMeters: 5000);
      final longer = cardioSession(day2, distanceMeters: 5001);
      final same = cardioSession(day2, distanceMeters: 5000);
      expect(detectCardioPrs(baseline, longer), [CardioPrType.longestDistance]);
      expect(detectCardioPrs(baseline, same), isEmpty);
    });

    test('a longer moving time fires for a GAME-family session too', () {
      const baseline = CardioPrBaseline(maxMovingSeconds: 3600);
      final session = cardioSession(day2, activityType: 'BASKETBALL', movingSeconds: 3601);
      expect(detectCardioPrs(baseline, session), [CardioPrType.longestMovingTime]);
    });

    test('elevation record never fires for an INDOOR_BIKE session even with a higher value', () {
      const baseline = CardioPrBaseline(maxElevationGainMeters: 100);
      final session =
          cardioSession(day2, activityType: 'INDOOR_BIKE', elevationGainMeters: 500);
      expect(detectCardioPrs(baseline, session), isEmpty);
    });

    test('elevation record fires for a HIKING session', () {
      const baseline = CardioPrBaseline(maxElevationGainMeters: 100);
      final session = cardioSession(day2, activityType: 'HIKING', elevationGainMeters: 101);
      expect(detectCardioPrs(baseline, session), [CardioPrType.greatestElevationGain]);
    });

    test('a single session can break multiple record types at once', () {
      const baseline = CardioPrBaseline(
        maxDistanceMeters: 5000,
        maxMovingSeconds: 1800,
        maxElevationGainMeters: 100,
      );
      final session = cardioSession(
        day2,
        activityType: 'RUNNING',
        distanceMeters: 6000,
        movingSeconds: 2000,
        elevationGainMeters: 150,
      );
      expect(
        detectCardioPrs(baseline, session),
        containsAll([
          CardioPrType.longestDistance,
          CardioPrType.longestMovingTime,
          CardioPrType.greatestElevationGain,
        ]),
      );
    });

    test('a STRENGTH session never produces a cardio PR, however generous the baseline', () {
      const baseline = CardioPrBaseline(
        maxDistanceMeters: 1,
        maxMovingSeconds: 1,
        maxElevationGainMeters: 1,
      );
      expect(detectCardioPrs(baseline, strengthSession(day2)), isEmpty);
    });

    test('a not-yet-finished cardio session never produces a PR', () {
      const baseline = CardioPrBaseline(maxDistanceMeters: 100);
      final session = cardioSession(day2, distanceMeters: 5000, finished: false);
      expect(detectCardioPrs(baseline, session), isEmpty);
    });
  });
}

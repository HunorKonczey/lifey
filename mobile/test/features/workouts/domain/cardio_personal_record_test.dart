import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/cardio_personal_record.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// Builds a baseline from plain "best so far" numbers. Since C6.7 a baseline
/// entry also carries *when* it was set (so a celebration can name the record
/// it replaced) — these tests only care about the values, so the date is a
/// fixed stand-in.
CardioPrBaseline _baseline({
  double? maxDistanceMeters,
  int? maxMovingSeconds,
  double? maxElevationGainMeters,
  int? best1kSeconds,
  int? best5kSeconds,
  int? best10kSeconds,
}) {
  final at = DateTime(2026, 1, 1);
  CardioPrBest? best(num? value) =>
      value == null ? null : CardioPrBest(value: value.toDouble(), at: at);
  return CardioPrBaseline(
    longestDistance: best(maxDistanceMeters),
    longestMovingTime: best(maxMovingSeconds),
    greatestElevationGain: best(maxElevationGainMeters),
    fastest1k: best(best1kSeconds),
    fastest5k: best(best5kSeconds),
    fastest10k: best(best10kSeconds),
  );
}

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
    int? best1kSeconds,
    int? best5kSeconds,
    int? best10kSeconds,
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
      cardio: (distanceMeters == null &&
              elevationGainMeters == null &&
              best1kSeconds == null &&
              best5kSeconds == null &&
              best10kSeconds == null)
          ? null
          : CardioMetrics(
              distanceMeters: distanceMeters,
              elevationGainMeters: elevationGainMeters,
              best1kSeconds: best1kSeconds,
              best5kSeconds: best5kSeconds,
              best10kSeconds: best10kSeconds,
            ),
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
      final baseline = _baseline(maxDistanceMeters: 5000);
      final longer = cardioSession(day2, distanceMeters: 5001);
      final same = cardioSession(day2, distanceMeters: 5000);
      expect(detectCardioPrs(baseline, longer), [CardioPrType.longestDistance]);
      expect(detectCardioPrs(baseline, same), isEmpty);
    });

    test('a longer moving time fires for a GAME-family session too', () {
      final baseline = _baseline(maxMovingSeconds: 3600);
      final session = cardioSession(day2, activityType: 'BASKETBALL', movingSeconds: 3601);
      expect(detectCardioPrs(baseline, session), [CardioPrType.longestMovingTime]);
    });

    test('elevation record never fires for an INDOOR_BIKE session even with a higher value', () {
      final baseline = _baseline(maxElevationGainMeters: 100);
      final session =
          cardioSession(day2, activityType: 'INDOOR_BIKE', elevationGainMeters: 500);
      expect(detectCardioPrs(baseline, session), isEmpty);
    });

    test('elevation record fires for a HIKING session', () {
      final baseline = _baseline(maxElevationGainMeters: 100);
      final session = cardioSession(day2, activityType: 'HIKING', elevationGainMeters: 101);
      expect(detectCardioPrs(baseline, session), [CardioPrType.greatestElevationGain]);
    });

    test('a single session can break multiple record types at once', () {
      final baseline = _baseline(
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
      final baseline = _baseline(
        maxDistanceMeters: 1,
        maxMovingSeconds: 1,
        maxElevationGainMeters: 1,
      );
      expect(detectCardioPrs(baseline, strengthSession(day2)), isEmpty);
    });

    test('a not-yet-finished cardio session never produces a PR', () {
      final baseline = _baseline(maxDistanceMeters: 100);
      final session = cardioSession(day2, distanceMeters: 5000, finished: false);
      expect(detectCardioPrs(baseline, session), isEmpty);
    });
  });

  // -- Best-effort records (docs/cardio/60 C6.7) ---------------------------

  group('fastest 1/5/10 km', () {
    test('a quicker time breaks the record; equal and slower do not', () {
      final baseline = _baseline(best5kSeconds: 1400);

      expect(detectCardioPrs(baseline, cardioSession(day2, best5kSeconds: 1399)),
          [CardioPrType.fastest5k]);
      expect(detectCardioPrs(baseline, cardioSession(day2, best5kSeconds: 1400)), isEmpty);
      expect(detectCardioPrs(baseline, cardioSession(day2, best5kSeconds: 1500)), isEmpty);
    });

    test('the baseline keeps the quickest time, not the latest or the largest', () {
      final baseline = CardioPrBaseline.fromSessions([
        cardioSession(day1, best5kSeconds: 1500),
        cardioSession(day2, best5kSeconds: 1380),
        cardioSession(day3, best5kSeconds: 1450),
      ]);

      expect(baseline.best5kSeconds, 1380);
      expect(baseline.fastest5k!.at, day2.add(const Duration(minutes: 30)));
    });

    test('only running sets these records — a walk never does', () {
      final walk = cardioSession(day2, activityType: 'WALKING', best5kSeconds: 1200);

      expect(CardioPrBaseline.fromSessions([walk]).best5kSeconds, isNull);
      expect(detectCardioPrs(_baseline(best5kSeconds: 1400), walk), isEmpty);
    });

    test('a hike never does either, however quick the number on it', () {
      final hike = cardioSession(day2, activityType: 'HIKING', best5kSeconds: 900);

      expect(CardioPrBaseline.fromSessions([hike]).best5kSeconds, isNull);
      expect(detectCardioPrs(_baseline(best5kSeconds: 1400), hike), isEmpty);
    });

    test('a run without that sub-distance breaks nothing', () {
      // A 3 km run has no 5 km inside it: `best5kSeconds` is null, which is
      // "this distance does not exist here", not "a slow time".
      final short = cardioSession(day2, distanceMeters: 3000, best1kSeconds: 240);

      expect(detectCardioPrs(_baseline(best5kSeconds: 1400), short), isEmpty);
    });

    test('the first run of a distance sets the bar rather than breaking one', () {
      final first = cardioSession(day2, best10kSeconds: 2980);

      expect(detectCardioPrs(CardioPrBaseline.empty, first), isEmpty);
      expect(CardioPrBaseline.fromSessions([first]).best10kSeconds, 2980);
    });

    test('one run can break all four running records at once (M36)', () {
      final baseline = _baseline(
        maxDistanceMeters: 11000,
        best1kSeconds: 260,
        best5kSeconds: 1400,
        best10kSeconds: 3000,
      );
      final session = cardioSession(
        day2,
        distanceMeters: 12000,
        best1kSeconds: 250,
        best5kSeconds: 1380,
        best10kSeconds: 2950,
      );

      expect(
        detectCardioPrs(baseline, session),
        containsAll([
          CardioPrType.longestDistance,
          CardioPrType.fastest1k,
          CardioPrType.fastest5k,
          CardioPrType.fastest10k,
        ]),
      );
    });

    test('the baseline remembers what each record was and when', () {
      // What the celebration needs to say "előző: 23:20 · július 1." (M36).
      final baseline = CardioPrBaseline.fromSessions([
        cardioSession(day1, best5kSeconds: 1400),
      ]);

      final previous = baseline[CardioPrType.fastest5k]!;
      expect(previous.value, 1400);
      expect(previous.at, day1.add(const Duration(minutes: 30)));
    });
  });
}

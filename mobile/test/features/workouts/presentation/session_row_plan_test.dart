import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/session_row_plan.dart';

void main() {
  group('with a stored plan', () {
    test('fills the plan up with blank rows', () {
      final plan = planSessionRows(
        storedTargetSets: 4,
        templateTargetSets: null,
        doneSets: 1,
        sessionFinished: false,
      );
      expect(plan.targetSets, 4);
      expect(plan.blankRows, 3);
    });

    test('a fully logged exercise keeps no blank row', () {
      final plan = planSessionRows(
        storedTargetSets: 3,
        templateTargetSets: null,
        doneSets: 3,
        sessionFinished: false,
      );
      expect(plan.blankRows, 0);
    });

    test('logging past the plan keeps no blank row either', () {
      final plan = planSessionRows(
        storedTargetSets: 3,
        templateTargetSets: null,
        doneSets: 5,
        sessionFinished: false,
      );
      expect(plan.blankRows, 0);
    });

    test('wins over the template fallback', () {
      final plan = planSessionRows(
        storedTargetSets: 2,
        templateTargetSets: 5,
        doneSets: 0,
        sessionFinished: false,
      );
      expect(plan.targetSets, 2);
      expect(plan.blankRows, 2);
    });
  });

  group('when the stored plan was lost on a server round-trip', () {
    test('falls back to the template count', () {
      final plan = planSessionRows(
        storedTargetSets: null,
        templateTargetSets: 4,
        doneSets: 1,
        sessionFinished: false,
      );
      expect(plan.targetSets, 4);
      expect(plan.blankRows, 3);
    });

    test('a running session with no plan at all still gets a row to log into',
        () {
      final plan = planSessionRows(
        storedTargetSets: null,
        templateTargetSets: null,
        doneSets: 2,
        sessionFinished: false,
      );
      expect(plan.targetSets, isNull);
      expect(plan.blankRows, 1);
    });

    test('template fallback exhausted mid-workout still leaves nothing open',
        () {
      // Every planned set is done: the "+ Add set" button (or the watch's
      // append path) takes over from here, exactly as with a stored plan.
      final plan = planSessionRows(
        storedTargetSets: null,
        templateTargetSets: 3,
        doneSets: 3,
        sessionFinished: false,
      );
      expect(plan.blankRows, 0);
    });
  });

  group('finished sessions', () {
    test('are not decorated with a blank row they never had', () {
      final plan = planSessionRows(
        storedTargetSets: null,
        templateTargetSets: null,
        doneSets: 3,
        sessionFinished: true,
      );
      expect(plan.blankRows, 0);
    });

    test('an exercise that logged nothing still shows one empty row', () {
      final plan = planSessionRows(
        storedTargetSets: null,
        templateTargetSets: null,
        doneSets: 0,
        sessionFinished: true,
      );
      expect(plan.blankRows, 1);
    });
  });

  test('an exercise with no sets and no plan shows a single empty row', () {
    final plan = planSessionRows(
      storedTargetSets: null,
      templateTargetSets: null,
      doneSets: 0,
      sessionFinished: false,
    );
    expect(plan.blankRows, 1);
  });

  group('cardioCardPrimaryMetric', () {
    WorkoutSession session({
      required String activityType,
      CardioMetrics? cardio,
      int? movingSeconds,
      DateTime? finishedAt,
    }) {
      final startedAt = DateTime(2026, 8, 10, 7);
      return WorkoutSession(
        clientId: 'c1',
        exercises: const [],
        sets: const [],
        startedAt: startedAt,
        finishedAt: finishedAt,
        sessionKind: 'CARDIO',
        activityType: activityType,
        movingSeconds: movingSeconds,
        cardio: cardio,
      );
    }

    test('DISTANCE shows the distance, the "cél alakú" number', () {
      final metric = cardioCardPrimaryMetric(
        session(
          activityType: 'RUNNING',
          cardio: const CardioMetrics(distanceMeters: 5000),
          movingSeconds: 1512,
        ),
        UnitSystem.metric,
      );
      expect(metric, '5.00 km');
    });

    test('DISTANCE without a distance falls back to the duration', () {
      final metric = cardioCardPrimaryMetric(
        session(activityType: 'WALKING', movingSeconds: 1830),
        UnitSystem.metric,
      );
      expect(metric, '30:30');
    });

    test('MACHINE always shows the moving duration, never the distance', () {
      final metric = cardioCardPrimaryMetric(
        session(
          activityType: 'INDOOR_BIKE',
          cardio: const CardioMetrics(distanceMeters: 18400),
          movingSeconds: 2538,
        ),
        UnitSystem.metric,
      );
      expect(metric, '42:18');
    });

    test('GAME shows the playing time', () {
      final metric = cardioCardPrimaryMetric(
        session(activityType: 'BASKETBALL', movingSeconds: 3120),
        UnitSystem.metric,
      );
      expect(metric, '52:00');
    });

    test('respects the imperial unit system for distance', () {
      final metric = cardioCardPrimaryMetric(
        session(
          activityType: 'RUNNING',
          cardio: const CardioMetrics(distanceMeters: 1609.344),
          movingSeconds: 600,
        ),
        UnitSystem.imperial,
      );
      expect(metric, '1.00 mi');
    });

    test('null for a STRENGTH session', () {
      final strength = WorkoutSession(
        clientId: 'c2',
        exercises: const [],
        sets: const [],
        startedAt: DateTime(2026, 8, 10, 7),
      );
      expect(cardioCardPrimaryMetric(strength, UnitSystem.metric), isNull);
    });

    test('null while a cardio session has neither distance nor duration yet', () {
      final metric = cardioCardPrimaryMetric(
        session(activityType: 'RUNNING'),
        UnitSystem.metric,
      );
      expect(metric, isNull);
    });
  });
}

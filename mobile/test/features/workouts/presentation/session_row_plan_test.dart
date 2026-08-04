import 'package:flutter_test/flutter_test.dart';
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
}

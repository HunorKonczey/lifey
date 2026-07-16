import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/personal_record.dart';

void main() {
  final day1 = DateTime(2026, 7, 1);
  final day2 = DateTime(2026, 7, 8);
  final day3 = DateTime(2026, 7, 15);

  group('estimateOneRepMax', () {
    test('applies the Epley formula', () {
      expect(estimateOneRepMax(100, 10), closeTo(133.33, 0.01));
      expect(estimateOneRepMax(100, 0), 100);
    });
  });

  group('PrBaseline.fromSets', () {
    test('empty history has no baseline values', () {
      final baseline = PrBaseline.fromSets(const []);
      expect(baseline.maxWeight, isNull);
      expect(baseline.bestOneRm, isNull);
      expect(baseline.maxRepsByWeight, isEmpty);
    });

    test('tracks max weight, best e1RM, and max reps per weight', () {
      final baseline = PrBaseline.fromSets([
        (weight: 80.0, reps: 10, performedAt: day1),
        (weight: 100.0, reps: 5, performedAt: day2),
        (weight: 80.0, reps: 12, performedAt: day3),
      ]);

      expect(baseline.maxWeight, 100.0);
      expect(baseline.bestOneRm, estimateOneRepMax(100.0, 5));
      expect(baseline.maxRepsByWeight[80.0], 12);
      expect(baseline.maxRepsByWeight[100.0], 5);
    });

    test('excludes 0 kg (bodyweight) sets from max weight and e1RM', () {
      final baseline = PrBaseline.fromSets([
        (weight: 0.0, reps: 20, performedAt: day1),
      ]);

      expect(baseline.maxWeight, isNull);
      expect(baseline.bestOneRm, isNull);
      expect(baseline.maxRepsByWeight[0.0], 20);
    });
  });

  group('PrBaseline.extend', () {
    test('folds a single set into an empty baseline the same as fromSets', () {
      final extended = PrBaseline.empty.extend(
        (weight: 60.0, reps: 8, performedAt: day1),
      );
      final fromSets = PrBaseline.fromSets([
        (weight: 60.0, reps: 8, performedAt: day1),
      ]);

      expect(extended.maxWeight, fromSets.maxWeight);
      expect(extended.bestOneRm, fromSets.bestOneRm);
      expect(extended.maxRepsByWeight, fromSets.maxRepsByWeight);
    });

    test('running baseline advances across two sets in one session', () {
      var baseline = PrBaseline.empty;
      baseline = baseline.extend((weight: 100.0, reps: 5, performedAt: day1));
      expect(baseline.maxWeight, 100.0);

      baseline = baseline.extend((weight: 105.0, reps: 5, performedAt: day1));
      expect(baseline.maxWeight, 105.0);
    });
  });

  group('detectPrs', () {
    test('no baseline -> no record fires for any type', () {
      final types = detectPrs(PrBaseline.empty, weight: 100, reps: 5);
      expect(types, isEmpty);
    });

    test('strictly greater weight is a max-weight PR; equal is not', () {
      final baseline = PrBaseline.fromSets([
        (weight: 100.0, reps: 5, performedAt: day1),
      ]);

      expect(
        detectPrs(baseline, weight: 105, reps: 5),
        contains(PrType.maxWeight),
      );
      expect(
        detectPrs(baseline, weight: 100, reps: 5),
        isNot(contains(PrType.maxWeight)),
      );
    });

    test('reps-at-weight requires a prior set at that exact weight', () {
      final baseline = PrBaseline.fromSets([
        (weight: 80.0, reps: 8, performedAt: day1),
      ]);

      // Never-before-used weight -> not a reps PR, even with more reps.
      expect(
        detectPrs(baseline, weight: 60, reps: 20),
        isNot(contains(PrType.repsAtWeight)),
      );
      // Same weight, more reps -> a reps PR.
      expect(
        detectPrs(baseline, weight: 80, reps: 9),
        contains(PrType.repsAtWeight),
      );
      // Same weight, equal reps -> not a PR.
      expect(
        detectPrs(baseline, weight: 80, reps: 8),
        isNot(contains(PrType.repsAtWeight)),
      );
    });

    test('estimated 1RM PR fires only when it beats the prior best', () {
      final baseline = PrBaseline.fromSets([
        (weight: 100.0, reps: 5, performedAt: day1),
      ]);

      expect(
        detectPrs(baseline, weight: 100, reps: 8),
        contains(PrType.estimatedOneRm),
      );
      expect(
        detectPrs(baseline, weight: 90, reps: 5),
        isNot(contains(PrType.estimatedOneRm)),
      );
    });

    test('weight 0 sets are eligible only for reps-at-weight', () {
      final baseline = PrBaseline.fromSets([
        (weight: 0.0, reps: 15, performedAt: day1),
      ]);

      final types = detectPrs(baseline, weight: 0, reps: 20);
      expect(types, [PrType.repsAtWeight]);
    });

    test('one set can break multiple record types at once', () {
      final baseline = PrBaseline.fromSets([
        (weight: 100.0, reps: 5, performedAt: day1),
      ]);

      final types = detectPrs(baseline, weight: 110, reps: 6);
      expect(types, containsAll([PrType.maxWeight, PrType.estimatedOneRm]));
    });
  });

  group('computePrHistory', () {
    test('empty history has no events', () {
      expect(computePrHistory(const []), isEmpty);
    });

    test('first set ever logged is never a PR (no baseline to beat)', () {
      final events = computePrHistory([
        (weight: 100.0, reps: 5, performedAt: day1),
      ]);
      expect(events, isEmpty);
    });

    test('a plateau (repeating the same set) produces no further events', () {
      final events = computePrHistory([
        (weight: 100.0, reps: 5, performedAt: day1),
        (weight: 100.0, reps: 5, performedAt: day2),
        (weight: 100.0, reps: 5, performedAt: day3),
      ]);
      expect(events, isEmpty);
    });

    test('progressive overload produces an event per improvement', () {
      final events = computePrHistory([
        (weight: 100.0, reps: 5, performedAt: day1),
        (weight: 105.0, reps: 5, performedAt: day2),
        (weight: 105.0, reps: 6, performedAt: day3),
      ]);

      // day2: max weight + e1RM PR. day3: e1RM + reps-at-105 PR.
      expect(events.where((e) => e.performedAt == day2).map((e) => e.type),
          containsAll([PrType.maxWeight, PrType.estimatedOneRm]));
      expect(events.where((e) => e.performedAt == day3).map((e) => e.type),
          containsAll([PrType.repsAtWeight, PrType.estimatedOneRm]));
      expect(
        events.where((e) => e.performedAt == day3 && e.type == PrType.maxWeight),
        isEmpty,
      );
    });

    test('interleaved types accumulate independently across weights', () {
      final events = computePrHistory([
        (weight: 60.0, reps: 8, performedAt: day1),
        (weight: 80.0, reps: 5, performedAt: day2),
        (weight: 60.0, reps: 10, performedAt: day3),
      ]);

      // day3 is a reps-at-60kg PR even though 80kg (a different weight) was
      // logged in between and is the current max weight.
      expect(
        events.where((e) => e.performedAt == day3).map((e) => e.type),
        contains(PrType.repsAtWeight),
      );
    });
  });

  group('detectPrsInOrder', () {
    test('empty input yields an empty result', () {
      expect(detectPrsInOrder(PrBaseline.empty, const []), isEmpty);
    });

    test('one record list per input position, in order', () {
      final baseline = PrBaseline.fromSets([
        (weight: 100.0, reps: 5, performedAt: day1),
      ]);

      final result = detectPrsInOrder(baseline, [
        (weight: 100.0, reps: 5, performedAt: day2), // matches baseline: no PR
        (weight: 105.0, reps: 5, performedAt: day3), // max weight + e1RM PR
      ]);

      expect(result, hasLength(2));
      expect(result[0], isEmpty);
      expect(result[1], containsAll([PrType.maxWeight, PrType.estimatedOneRm]));
    });

    test('running baseline carries across positions within the call', () {
      // Starting from an empty baseline (first-ever exercise), the second
      // set should be compared against the first, not against nothing.
      final result = detectPrsInOrder(PrBaseline.empty, [
        (weight: 100.0, reps: 5, performedAt: day1), // no baseline yet: no PR
        (weight: 105.0, reps: 5, performedAt: day2), // beats set 1
      ]);

      expect(result[0], isEmpty);
      expect(result[1], isNotEmpty);
    });
  });
}

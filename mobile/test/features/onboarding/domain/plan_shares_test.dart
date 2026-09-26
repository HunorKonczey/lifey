import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/onboarding/domain/plan_shares.dart';

void main() {
  group('macroPercents', () {
    test('the canvas plan: 129 g protein, 313 g carbs, 66 g fat → 22 / 53 / 25', () {
      expect(macroPercents(proteinGrams: 129, carbsGrams: 313, fatGrams: 66), [22, 53, 25]);
    });

    test('always adds up to 100, however the parts round', () {
      for (final (p, c, f) in [(100, 100, 100), (33, 33, 34), (150, 200, 50), (1, 1, 1), (250, 100, 80)]) {
        final shares = macroPercents(proteinGrams: p, carbsGrams: c, fatGrams: f);
        expect(shares.fold<int>(0, (a, b) => a + b), 100, reason: '$p/$c/$f -> $shares');
      }
    });

    test('fat counts nine kilocalories a gram, protein and carbs four', () {
      // 100 g each: 400 + 400 + 900 = 1 700 kcal.
      expect(macroPercents(proteinGrams: 100, carbsGrams: 100, fatGrams: 100), [24, 23, 53]); // 23.5 / 23.5 / 52.9
    });

    test('an empty plan is 0 / 0 / 0, not a division by zero', () {
      expect(macroPercents(proteinGrams: 0, carbsGrams: 0, fatGrams: 0), [0, 0, 0]);
    });
  });

  group('calorieAdjustmentPercent', () {
    test('a surplus is positive, a deficit negative, maintenance zero', () {
      expect(calorieAdjustmentPercent(calories: 2360, tdee: 2145), 10);
      expect(calorieAdjustmentPercent(calories: 1830, tdee: 2145), -15);
      expect(calorieAdjustmentPercent(calories: 2145, tdee: 2145), 0);
    });

    test('a tdee of zero gives no adjustment rather than infinity', () {
      expect(calorieAdjustmentPercent(calories: 2000, tdee: 0), 0);
    });
  });
}

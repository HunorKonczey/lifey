import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/daily_macros.dart';
import 'package:lifey/features/nutrition/domain/remaining_budget.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';

DailyMacros _day({double calories = 0, double protein = 0}) => DailyMacros(
      day: DateTime(2026, 7, 10),
      calories: calories,
      protein: protein,
      carbs: 0,
      fat: 0,
    );

UserSettings _settings({int? calorieGoal, int? proteinGoal}) => UserSettings(
      unitSystem: UnitSystem.metric,
      theme: ThemePreference.system,
      language: LanguagePreference.system,
      dailyCalorieGoal: calorieGoal,
      dailyProteinGoal: proteinGoal,
    );

void main() {
  group('RemainingBudget.compute', () {
    test('no goals set → both metrics report no goal', () {
      final budget = RemainingBudget.compute(_day(calories: 500), const UserSettings.defaults());

      expect(budget.calories.hasGoal, isFalse);
      expect(budget.calories.remaining, isNull);
      expect(budget.protein.hasGoal, isFalse);
      expect(budget.hasAnyGoal, isFalse);
    });

    test('under budget → positive remaining, not over', () {
      final day = _day(calories: 1460, protein: 90);
      final settings = _settings(calorieGoal: 2200, proteinGoal: 150);

      final budget = RemainingBudget.compute(day, settings);

      expect(budget.calories.remaining, 740);
      expect(budget.calories.isOver, isFalse);
      expect(budget.protein.remaining, 60);
      expect(budget.hasAnyGoal, isTrue);
    });

    test('over budget → negative remaining, isOver true, never clamped', () {
      final day = _day(calories: 2500, protein: 40);
      final settings = _settings(calorieGoal: 2200, proteinGoal: 150);

      final budget = RemainingBudget.compute(day, settings);

      expect(budget.calories.remaining, -300);
      expect(budget.calories.isOver, isTrue);
    });

    test('only one goal set → other metric reports no goal', () {
      final day = _day(calories: 500, protein: 40);
      final settings = _settings(calorieGoal: 2200);

      final budget = RemainingBudget.compute(day, settings);

      expect(budget.calories.hasGoal, isTrue);
      expect(budget.protein.hasGoal, isFalse);
      expect(budget.hasAnyGoal, isTrue);
    });

    test('no meals logged today (null bucket) → consumed treated as zero', () {
      final settings = _settings(calorieGoal: 2200, proteinGoal: 150);

      final budget = RemainingBudget.compute(null, settings);

      expect(budget.calories.consumed, 0);
      expect(budget.calories.remaining, 2200);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/nutrition/domain/meal_budget_preview.dart';

Meal _meal(String id, double kcal) => Meal(
      clientId: id,
      dateTime: DateTime(2026, 9, 24, 12),
      mealType: MealType.lunch,
      entries: [
        MealEntry(
          foodClientId: 'f-$id',
          foodName: id,
          quantityInGrams: 100,
          calories: kcal,
          protein: 0,
          carbs: 0,
          fat: 0,
        ),
      ],
    );

void main() {
  // The canvas day: 2 360 kcal goal, breakfast 383 + snack 238 already logged,
  // and the meal being edited is the 383 breakfast.
  final breakfast = _meal('breakfast', 383);
  final snack = _meal('snack', 238);

  group('othersKcalOf', () {
    test('a new meal that is not saved yet: every logged meal is "other"', () {
      expect(MealBudgetPreview.othersKcalOf([breakfast, snack]), 621);
    });

    test('an edited meal leaves out its own saved version', () {
      expect(MealBudgetPreview.othersKcalOf([breakfast, snack], excludeClientId: 'breakfast'), 238);
    });

    test('a meal autosaved from this editor counts as the meal, not as another', () {
      // A new meal whose first entry was autosaved has a client id and is in
      // the day's list; excluding it avoids counting the draft twice.
      final saved = _meal('draft', 145);
      expect(MealBudgetPreview.othersKcalOf([saved, snack], excludeClientId: 'draft'), 238);
    });

    test('an empty day has no other meals', () {
      expect(MealBudgetPreview.othersKcalOf(const []), 0);
    });
  });

  group('remaining', () {
    test('a new 145 kcal banana onto the 621 kcal day leaves 1 594', () {
      const preview = MealBudgetPreview(goal: 2360, othersKcal: 621, draftKcal: 145);
      expect(preview.afterKcal, 766);
      expect(preview.remaining, 1594);
      expect(preview.isOver, isFalse);
    });

    test('the edited 383 kcal breakfast: 2 360 − (238 + 383) = 1 739, not 1 356 (the saved copy is not counted twice)', () {
      final preview = MealBudgetPreview(
        goal: 2360,
        othersKcal: MealBudgetPreview.othersKcalOf([breakfast, snack], excludeClientId: 'breakfast'),
        draftKcal: 383,
      );
      expect(preview.remaining, 1739);
    });

    test('editing the breakfast down to 200 kcal frees the difference', () {
      final preview = MealBudgetPreview(
        goal: 2360,
        othersKcal: MealBudgetPreview.othersKcalOf([breakfast, snack], excludeClientId: 'breakfast'),
        draftKcal: 200,
      );
      expect(preview.remaining, 1922);
    });

    test('past the goal the remaining is negative and the preview says over', () {
      const preview = MealBudgetPreview(goal: 2000, othersKcal: 1800, draftKcal: 412);
      expect(preview.remaining, -212);
      expect(preview.isOver, isTrue);
    });

    test('exactly at the goal is not over', () {
      const preview = MealBudgetPreview(goal: 2000, othersKcal: 1800, draftKcal: 200);
      expect(preview.remaining, 0);
      expect(preview.isOver, isFalse);
    });
  });
}

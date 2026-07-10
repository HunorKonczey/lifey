import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/day_meals_summary.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';

/// Anchors every test's dates relative to "now" rather than hard-coding
/// calendar dates, so the suite never goes stale or flakes around a fixed
/// date. [offset] is days back from today's local midnight.
final _now = DateTime.now();
DateTime _day(int offset) =>
    DateTime(_now.year, _now.month, _now.day).subtract(Duration(days: offset));

Meal _meal(DateTime dateTime, {double calories = 100}) => Meal(
      clientId: 'meal-${dateTime.microsecondsSinceEpoch}-$calories',
      dateTime: dateTime,
      mealType: MealType.lunch,
      entries: [
        MealEntry(
          foodClientId: 'food',
          foodName: 'Food',
          quantityInGrams: 100,
          calories: calories,
          protein: 10,
          carbs: 0,
          fat: 0,
        ),
      ],
    );

void main() {
  test('groups meals by local calendar day, newest first', () {
    final meals = [
      _meal(_day(2).add(const Duration(hours: 8)), calories: 300),
      _meal(_day(0).add(const Duration(hours: 12)), calories: 500),
      _meal(_day(2).add(const Duration(hours: 19)), calories: 200),
    ];

    final days = groupMealsByDay(meals);

    expect(days, hasLength(2));
    expect(days[0].day, _day(0));
    expect(days[0].mealCount, 1);
    expect(days[0].totalCalories, 500);
    expect(days[1].day, _day(2));
    expect(days[1].mealCount, 2);
    expect(days[1].totalCalories, 500);
  });

  test('returns an empty list for no meals', () {
    expect(groupMealsByDay(const []), isEmpty);
  });

  test('a meal exactly at local midnight belongs to that day, not the previous one', () {
    final days = groupMealsByDay([_meal(_day(1))]);
    expect(days.single.day, _day(1));
  });
}

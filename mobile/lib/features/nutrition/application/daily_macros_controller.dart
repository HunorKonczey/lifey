import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/daily_macros.dart';
import '../domain/meal.dart';
import 'meal_controller.dart';

/// Derives per-day macro totals from the currently loaded meal pages.
///
/// Aggregates the in-memory meal list from [mealControllerProvider] — each
/// meal's totalCalories/totalProtein/totalCarbs/totalFat is bucketed into its
/// local calendar day, yielding one [DailyMacros] per day, sorted newest first.
///
/// Accuracy note: [MealController] is paginated (40 meals per page by default).
/// For Today and Week filters the loaded window is always complete, so the
/// aggregated totals are exact. For "All" some older days may be missing until
/// the user scrolls far enough in the Meals tab to load them.
/// TODO: replace with a Drift-level daily aggregation query in MealRepository
/// (watchDailyMacros) to make the "All" view fully accurate without pagination.
final dailyMacrosProvider = Provider<AsyncValue<List<DailyMacros>>>((ref) {
  final mealsAsync = ref.watch(mealControllerProvider);
  return mealsAsync.whenData(_aggregate);
});

List<DailyMacros> _aggregate(List<Meal> meals) {
  final byDay = <DateTime, _Accumulator>{};

  for (final meal in meals) {
    final local = meal.dateTime.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    (byDay[day] ??= _Accumulator()).add(meal);
  }

  final result = byDay.entries
      .map((e) => DailyMacros(
            day: e.key,
            calories: e.value.calories,
            protein: e.value.protein,
            carbs: e.value.carbs,
            fat: e.value.fat,
          ))
      .toList()
    ..sort((a, b) => b.day.compareTo(a.day));

  return result;
}

class _Accumulator {
  double calories = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;

  void add(Meal meal) {
    calories += meal.totalCalories;
    protein += meal.totalProtein;
    carbs += meal.totalCarbs;
    fat += meal.totalFat;
  }
}

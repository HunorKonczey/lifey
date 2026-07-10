import 'meal.dart';

/// A calendar day's worth of logged meals, for "copy a previous day" pickers.
class DayMealsSummary {
  const DayMealsSummary({required this.day, required this.meals});

  /// Local midnight of the summarized day.
  final DateTime day;
  final List<Meal> meals;

  int get mealCount => meals.length;

  double get totalCalories => meals.fold(0, (sum, m) => sum + m.totalCalories);
}

/// Groups [meals] by local calendar day, newest day first.
List<DayMealsSummary> groupMealsByDay(List<Meal> meals) {
  final byDay = <DateTime, List<Meal>>{};
  for (final meal in meals) {
    final local = meal.dateTime.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    byDay.putIfAbsent(day, () => []).add(meal);
  }
  final days = byDay.entries
      .map((e) => DayMealsSummary(day: e.key, meals: e.value))
      .toList()
    ..sort((a, b) => b.day.compareTo(a.day));
  return days;
}

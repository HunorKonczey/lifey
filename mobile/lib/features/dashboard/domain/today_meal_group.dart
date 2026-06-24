import '../../nutrition/domain/meal.dart';

/// Today's logged meals for a single [MealType], used by the dashboard section.
class TodayMealGroup {
  const TodayMealGroup({required this.type, required this.meals});

  final MealType type;
  final List<Meal> meals;

  double get totalCalories => meals.fold(0.0, (s, m) => s + m.totalCalories);
}

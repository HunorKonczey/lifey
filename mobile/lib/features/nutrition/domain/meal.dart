/// Meal type enumeration.
enum MealType { breakfast, lunch, dinner, snack }

/// Domain model for a logged meal.
class Meal {
  const Meal({
    required this.id,
    required this.dateTime,
    required this.mealType,
  });

  final int id;
  final DateTime dateTime;
  final MealType mealType;
}

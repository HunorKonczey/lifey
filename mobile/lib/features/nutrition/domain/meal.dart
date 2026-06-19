/// The four meal types supported by the backend.
enum MealType {
  breakfast('BREAKFAST', 'Breakfast'),
  lunch('LUNCH', 'Lunch'),
  dinner('DINNER', 'Dinner'),
  snack('SNACK', 'Snack');

  const MealType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MealType fromApi(String value) =>
      values.firstWhere((e) => e.apiValue == value, orElse: () => MealType.snack);
}

/// A single food entry within a meal (response side). Macros are computed
/// locally (quantity × the food's per-100g values) rather than fetched from
/// the backend, so they're available offline too.
class MealEntry {
  const MealEntry({
    required this.foodClientId,
    required this.foodName,
    required this.quantityInGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String foodClientId;
  final String foodName;
  final double quantityInGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
}

/// A logged meal (`/meals`).
class Meal {
  const Meal({
    required this.clientId,
    required this.dateTime,
    required this.mealType,
    required this.entries,
    this.id,
  });

  final String clientId;
  final int? id;
  final DateTime dateTime;
  final MealType mealType;
  final List<MealEntry> entries;

  double get totalCalories => entries.fold(0, (sum, e) => sum + e.calories);

  double get totalProtein => entries.fold(0, (sum, e) => sum + e.protein);

  double get totalCarbs => entries.fold(0, (sum, e) => sum + e.carbs);

  double get totalFat => entries.fold(0, (sum, e) => sum + e.fat);
}

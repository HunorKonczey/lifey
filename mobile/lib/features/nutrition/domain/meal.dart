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

/// A single food entry within a meal (response side).
class MealEntry {
  const MealEntry({
    required this.foodId,
    required this.foodName,
    required this.quantityInGrams,
    required this.calories,
    required this.protein,
  });

  final int foodId;
  final String foodName;
  final double quantityInGrams;
  final double calories;
  final double protein;

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    return MealEntry(
      foodId: json['foodId'] as int,
      foodName: json['foodName'] as String? ?? 'Unknown',
      quantityInGrams: (json['quantityInGrams'] as num).toDouble(),
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A logged meal (`/meals`).
class Meal {
  const Meal({
    required this.id,
    required this.dateTime,
    required this.mealType,
    required this.entries,
  });

  final int id;
  final DateTime dateTime;
  final MealType mealType;
  final List<MealEntry> entries;

  double get totalCalories =>
      entries.fold(0, (sum, e) => sum + e.calories);

  double get totalProtein =>
      entries.fold(0, (sum, e) => sum + e.protein);

  factory Meal.fromJson(Map<String, dynamic> json) {
    final entries = (json['entries'] as List<dynamic>? ?? const [])
        .map((e) => MealEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return Meal(
      id: json['id'] as int,
      dateTime: DateTime.parse(json['dateTime'] as String),
      mealType: MealType.fromApi(json['mealType'] as String),
      entries: entries,
    );
  }
}

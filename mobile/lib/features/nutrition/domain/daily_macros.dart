/// Aggregated macro totals for a single calendar day (local midnight).
class DailyMacros {
  const DailyMacros({
    required this.day,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  /// Local midnight of the calendar day these totals belong to.
  final DateTime day;

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
}

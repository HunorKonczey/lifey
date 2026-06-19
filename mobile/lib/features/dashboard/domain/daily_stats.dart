/// Today's aggregated nutrition + workout summary, computed locally from
/// the already-migrated feature repositories (meals, sessions, weight,
/// water) — see `dashboardControllerProvider`.
class DailyStats {
  const DailyStats({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.workoutCount,
    required this.water,
    this.latestWeight,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int workoutCount;
  final double water;
  final double? latestWeight;
}

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
    this.strengthWorkoutCount = 0,
    this.cardioWorkoutCount = 0,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int workoutCount;
  final double water;
  final double? latestWeight;

  /// [workoutCount] broken down by kind (docs/cardio/56-cardio-statistics-plan.md
  /// §4: "Az „edzések" szám alá egy halk bontás-sor") — always
  /// [strengthWorkoutCount] + [cardioWorkoutCount] == [workoutCount], since
  /// every session is exactly one or the other.
  final int strengthWorkoutCount;
  final int cardioWorkoutCount;
}

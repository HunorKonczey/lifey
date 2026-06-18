/// Today's aggregated nutrition + workout summary from `GET /statistics/daily`.
class DailyStats {
  const DailyStats({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.workoutCount,
    this.latestWeight,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int workoutCount;
  final double? latestWeight;

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    double num0(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return DailyStats(
      calories: num0('totalCalories'),
      protein: num0('totalProtein'),
      carbs: num0('totalCarbs'),
      fat: num0('totalFat'),
      workoutCount: (json['workoutCount'] as num?)?.toInt() ?? 0,
      latestWeight: (json['latestWeight'] as num?)?.toDouble(),
    );
  }
}

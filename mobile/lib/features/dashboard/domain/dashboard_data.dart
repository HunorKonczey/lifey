import '../../../shared/widgets/charts/time_series_chart.dart';
import 'daily_stats.dart';
import 'recent_workout.dart';
import 'today_meal_group.dart';

/// Everything the dashboard screen renders, loaded in one pass.
class DashboardData {
  const DashboardData({
    required this.stats,
    required this.recentWorkouts,
    required this.todaysMealGroups,
    required this.weeklyCalories,
  });

  final DailyStats stats;
  final List<RecentWorkout> recentWorkouts;
  final List<TodayMealGroup> todaysMealGroups;

  /// Last 7 days of calorie totals (oldest first), one point per day.
  final List<TimeSeriesPoint> weeklyCalories;
}

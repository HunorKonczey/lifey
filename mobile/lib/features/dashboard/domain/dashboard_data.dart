import 'daily_stats.dart';
import 'recent_workout.dart';

/// Everything the dashboard screen renders, loaded in one pass.
class DashboardData {
  const DashboardData({
    required this.stats,
    required this.recentWorkouts,
  });

  final DailyStats stats;
  final List<RecentWorkout> recentWorkouts;
}

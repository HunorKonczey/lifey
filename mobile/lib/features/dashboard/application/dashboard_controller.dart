import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/charts/time_series_chart.dart';
import '../../nutrition/application/meal_controller.dart';
import '../../nutrition/domain/meal.dart';
import '../../water/data/water_entry_repository.dart';
import '../../weight/application/weight_controller.dart';
import '../../workouts/application/workout_session_controller.dart';
import '../domain/daily_stats.dart';
import '../domain/dashboard_data.dart';
import '../domain/recent_workout.dart';
import '../domain/today_meal_group.dart';

const _recentWorkoutLimit = 5;

const _mealTypeOrder = [MealType.breakfast, MealType.lunch, MealType.dinner, MealType.snack];

List<TimeSeriesPoint> _buildWeeklyCalories(List<Meal> meals) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final result = <TimeSeriesPoint>[];
  for (var i = 6; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final total = meals
        .where((m) {
          final d = m.dateTime.toLocal();
          return d.year == day.year && d.month == day.month && d.day == day.day;
        })
        .fold(0.0, (sum, m) => sum + m.totalCalories);
    result.add(TimeSeriesPoint(date: day, value: total));
  }
  return result;
}

bool _isToday(DateTime dateTime) {
  final now = DateTime.now();
  final local = dateTime.toLocal();
  return local.year == now.year && local.month == now.month && local.day == now.day;
}

/// Combines today's meals, workout sessions, weight and water — all already
/// local-first — into the dashboard's view model.
///
/// This is a plain derived [Provider], not a [StreamNotifier]: it has no
/// network call and no async gap of its own, so it recomputes synchronously
/// whenever any of the providers it watches changes. That also means the
/// dashboard works fully offline — unlike the old version, which fetched
/// `/statistics/daily` and `/workout-sessions` directly and so depended on
/// connectivity for a screen that otherwise mostly aggregates a single
/// device's own already-local data.
final dashboardControllerProvider = Provider<DashboardData>((ref) {
  final meals = ref.watch(mealControllerProvider).value ?? const [];
  final sessions = ref.watch(workoutSessionControllerProvider).value ?? const [];
  final weights = ref.watch(weightControllerProvider).value ?? const [];
  final water = ref.watch(todayWaterTotalProvider).value ?? 0;

  final todaysMeals = meals.where((m) => _isToday(m.dateTime)).toList();
  final todaysSessionCount = sessions.where((s) => _isToday(s.startedAt)).length;

  final stats = DailyStats(
    calories: todaysMeals.fold(0.0, (sum, m) => sum + m.totalCalories),
    protein: todaysMeals.fold(0.0, (sum, m) => sum + m.totalProtein),
    carbs: todaysMeals.fold(0.0, (sum, m) => sum + m.totalCarbs),
    fat: todaysMeals.fold(0.0, (sum, m) => sum + m.totalFat),
    workoutCount: todaysSessionCount,
    water: water,
    latestWeight: weights.isEmpty ? null : weights.first.weight,
  );

  final todaysMealGroups = _mealTypeOrder
      .map((type) {
        final group = todaysMeals.where((m) => m.mealType == type).toList();
        return group.isEmpty ? null : TodayMealGroup(type: type, meals: group);
      })
      .whereType<TodayMealGroup>()
      .toList();

  // Already sorted newest-first by WorkoutSessionRepository.watchAll().
  final recentWorkouts = sessions.take(_recentWorkoutLimit).map((session) {
    final exerciseNames = <String>{for (final set in session.sets) set.exerciseName};
    return RecentWorkout(
      clientId: session.clientId,
      startedAt: session.startedAt,
      finishedAt: session.finishedAt,
      setCount: session.sets.length,
      exerciseNames: exerciseNames.toList(),
      activeCalories: session.activeCalories,
    );
  }).toList();

  final weeklyCalories = _buildWeeklyCalories(meals);

  return DashboardData(
    stats: stats,
    recentWorkouts: recentWorkouts,
    todaysMealGroups: todaysMealGroups,
    weeklyCalories: weeklyCalories,
  );
});

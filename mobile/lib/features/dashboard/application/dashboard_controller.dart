import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nutrition/application/meal_controller.dart';
import '../../water/data/water_entry_repository.dart';
import '../../weight/application/weight_controller.dart';
import '../../workouts/application/workout_session_controller.dart';
import '../domain/daily_stats.dart';
import '../domain/dashboard_data.dart';
import '../domain/recent_workout.dart';

const _recentWorkoutLimit = 5;

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

  final todaysMeals = meals.where((m) => _isToday(m.dateTime));
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

  // Already sorted newest-first by WorkoutSessionRepository.watchAll().
  final recentWorkouts = sessions.take(_recentWorkoutLimit).map((session) {
    final exerciseNames = <String>{for (final set in session.sets) set.exerciseName};
    return RecentWorkout(
      clientId: session.clientId,
      startedAt: session.startedAt,
      finishedAt: session.finishedAt,
      setCount: session.sets.length,
      exerciseNames: exerciseNames.toList(),
    );
  }).toList();

  return DashboardData(stats: stats, recentWorkouts: recentWorkouts);
});

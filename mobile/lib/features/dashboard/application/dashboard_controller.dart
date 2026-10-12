import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/charts/time_series_chart.dart';
import '../../nutrition/application/meal_controller.dart';
import '../../nutrition/domain/meal.dart';
import '../../water/data/water_entry_repository.dart';
import '../../weight/application/weight_controller.dart';
import '../../workouts/application/exercise_controller.dart';
import '../../workouts/domain/exercise_enums.dart';
import '../domain/daily_stats.dart';
import '../domain/dashboard_data.dart';
import '../domain/recent_workout.dart';
import '../domain/today_meal_group.dart';
import '../../workouts/application/workout_summaries_provider.dart';
import '../../workouts/data/workout_session_repository.dart';
import '../../workouts/domain/workout_session.dart';

const _recentWorkoutLimit = 5;

/// The newest few sessions *with* their sets - the recent-workouts card names the exercises and counts the sets, which the
/// summaries behind the rest of the dashboard do not carry (LIF-155). A bounded window, so the card costs the same however long the
/// history is; a couple more than shown, as a session being deleted drops out of the read before it leaves the table.
final recentWorkoutSessionsProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(workoutSessionRepositoryProvider).watchPaged(limit: _recentWorkoutLimit + 2);
});

const _mealTypeOrder = [MealType.breakfast, MealType.lunch, MealType.dinner, MealType.snack];

List<TimeSeriesPoint> _buildWeeklyCalories(List<Meal> meals) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final result = <TimeSeriesPoint>[];
  for (var i = 6; i >= 0; i--) {
    // Field arithmetic, not `subtract(Duration)`: across a DST change the
    // latter lands an hour off and would pick the wrong calendar day.
    final day = DateTime(today.year, today.month, today.day - i);
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
  // Upcoming (trainer-scheduled, not-yet-started) sessions aren't "workouts
  // that happened" — excluded here the same way the backend excludes them
  // from statistics/history (docs/personal_trainer/09-utemezett-edzesek-domain-backend.md).
  final sessions = (ref.watch(workoutSummariesProvider).value ?? const [])
      .where((s) => !s.isUpcoming)
      .toList();
  final exercises = ref.watch(exerciseControllerProvider).value ?? const [];
  final categoryByExercise = {
    for (final e in exercises) e.clientId: e.category,
  };
  final weights = ref.watch(weightControllerProvider).value ?? const [];
  final water = ref.watch(todayWaterTotalProvider).value ?? 0;

  final todaysMeals = meals.where((m) => _isToday(m.dateTime)).toList();
  final todaysSessions = sessions.where((s) => _isToday(s.startedAt!)).toList();
  final todaysSessionCount = todaysSessions.length;
  final todaysCardioCount = todaysSessions.where((s) => s.isCardio).length;

  final stats = DailyStats(
    calories: todaysMeals.fold(0.0, (sum, m) => sum + m.totalCalories),
    protein: todaysMeals.fold(0.0, (sum, m) => sum + m.totalProtein),
    carbs: todaysMeals.fold(0.0, (sum, m) => sum + m.totalCarbs),
    fat: todaysMeals.fold(0.0, (sum, m) => sum + m.totalFat),
    workoutCount: todaysSessionCount,
    water: water,
    latestWeight: weights.isEmpty ? null : weights.first.weight,
    strengthWorkoutCount: todaysSessionCount - todaysCardioCount,
    cardioWorkoutCount: todaysCardioCount,
  );

  final todaysMealGroups = _mealTypeOrder
      .map((type) {
        final group = todaysMeals.where((m) => m.mealType == type).toList();
        return group.isEmpty ? null : TodayMealGroup(type: type, meals: group);
      })
      .whereType<TodayMealGroup>()
      .toList();

  // Newest first, from the window that carries the sets; upcoming ones are not workouts that happened.
  final recentSessions = (ref.watch(recentWorkoutSessionsProvider).value ?? const <WorkoutSession>[]).where((s) => !s.isUpcoming);
  final recentWorkouts = recentSessions.take(_recentWorkoutLimit).map((session) {
    final exerciseNames = <String>{for (final set in session.sets) set.exerciseName};
    final exerciseIds = <String>{
      for (final ex in session.exercises) ex.exerciseClientId,
      for (final set in session.sets) set.exerciseClientId,
    };
    return RecentWorkout(
      clientId: session.clientId,
      startedAt: session.startedAt!,
      finishedAt: session.finishedAt,
      setCount: session.sets.length,
      exerciseNames: exerciseNames.toList(),
      activeCalories: session.activeCalories,
      categoryCode: dominantMuscleGroup(
        exerciseIds.map((id) => categoryByExercise[id]),
      ),
      templateName: session.templateName,
      rpe: session.rpe,
      sessionKind: session.sessionKind,
      activityType: session.activityType,
      distanceMeters: session.cardio?.distanceMeters,
      movingSeconds: session.movingSeconds,
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

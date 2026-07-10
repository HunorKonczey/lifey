import '../../settings/domain/user_settings.dart';
import 'daily_macros.dart';

/// One metric's consumed/goal/remaining figures for the day. `goal` is null
/// when the user hasn't set that daily goal — callers should hide the
/// remaining UI for that metric in that case rather than inventing a default.
class BudgetMetric {
  const BudgetMetric({
    required this.consumed,
    required this.goal,
  });

  final double consumed;
  final int? goal;

  bool get hasGoal => goal != null;

  /// Positive while under budget, negative once over. Null without a goal.
  double? get remaining => hasGoal ? goal! - consumed : null;

  bool get isOver => (remaining ?? 0) < 0;
}

/// Today's remaining calorie/protein budget, derived from today's logged
/// meals and the user's daily goals. Carbs/fat intentionally excluded — the
/// roadmap's "remaining budget" surface is calories + protein only.
class RemainingBudget {
  const RemainingBudget({required this.calories, required this.protein});

  final BudgetMetric calories;
  final BudgetMetric protein;

  /// True when at least one of the two goals is set, i.e. there's something
  /// worth rendering.
  bool get hasAnyGoal => calories.hasGoal || protein.hasGoal;

  factory RemainingBudget.compute(DailyMacros? today, UserSettings settings) {
    return RemainingBudget(
      calories: BudgetMetric(
        consumed: today?.calories ?? 0,
        goal: settings.dailyCalorieGoal,
      ),
      protein: BudgetMetric(
        consumed: today?.protein ?? 0,
        goal: settings.dailyProteinGoal,
      ),
    );
  }
}

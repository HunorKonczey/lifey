import 'meal.dart';

/// "Today after this meal": the day's calorie goal against the day's *other*
/// meals plus the meal being edited, so the editor can show what is left
/// while the meal is still a draft (docs/redesign/77-mobile-redesign-plan.md
/// R2.5; plan §9 risk 3).
///
/// The editor autosaves, so the meal being edited is usually already among
/// the day's saved meals — [othersKcal] leaves that saved version out, and
/// the draft's own total is [draftKcal]; otherwise every edit would count the
/// meal twice.
class MealBudgetPreview {
  const MealBudgetPreview({required this.goal, required this.othersKcal, required this.draftKcal});

  /// The day's calorie goal.
  final int goal;

  /// Calories of the day's other meals.
  final double othersKcal;

  /// Calories of the meal in the editor, as drafted right now.
  final double draftKcal;

  /// The day's calories with this meal counted.
  double get afterKcal => othersKcal + draftKcal;

  /// Goal minus [afterKcal]; negative once over.
  double get remaining => goal - afterKcal;

  bool get isOver => remaining < 0;

  /// Sum of the calories of [dayMeals] except the one with [excludeClientId]
  /// — the saved version of the meal being edited (null for a meal that has
  /// not been saved yet).
  static double othersKcalOf(List<Meal> dayMeals, {String? excludeClientId}) => dayMeals
      .where((m) => m.clientId != excludeClientId)
      .fold(0, (sum, m) => sum + m.totalCalories);
}

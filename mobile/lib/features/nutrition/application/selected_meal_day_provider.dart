import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meal_repository.dart';
import '../domain/meal.dart';

/// The day picked in the Meals tab's week strip; null = today. Read through
/// `effectiveMealDay` (domain/meal_days.dart), which drops a pick that has
/// scrolled out of the strip. Lives in a provider, not the tab's state,
/// because the "+ Meal" button in the shell logs onto the selected day.
class SelectedMealDay extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void select(DateTime? day) => state = day;
}

final selectedMealDayProvider =
    NotifierProvider<SelectedMealDay, DateTime?>(SelectedMealDay.new);

/// The meals of one local calendar day, newest first — the selected day of
/// the Meals tab. Independent of [mealControllerProvider]'s 40-meal page.
final mealsOnDayProvider = StreamProvider.family<List<Meal>, DateTime>((ref, day) {
  return ref.watch(mealRepositoryProvider).watchDay(day);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meal_repository.dart';
import '../domain/daily_macros.dart';

/// Per-day macro totals across full meal history, sorted newest first.
///
/// Backed by [MealRepository.watchDailyMacros] — a Drift-level aggregation
/// over *every* meal, not [mealControllerProvider]'s 40-meal UI page. Every
/// day (Today, Week, All) is therefore exact regardless of how far the Meals
/// tab has scrolled; this replaced an earlier version that aggregated the
/// paged meal list and was only exact for Today/Week.
final dailyMacrosProvider = StreamProvider<List<DailyMacros>>((ref) {
  return ref.watch(mealRepositoryProvider).watchDailyMacros();
});

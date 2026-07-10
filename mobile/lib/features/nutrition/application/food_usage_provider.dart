import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meal_repository.dart';
import '../domain/food_usage.dart';

/// Per-food usage stats (last used, count, last grams) for suggestion
/// ranking and the grams prefill in the add-entry sheet.
final foodUsageProvider = StreamProvider.autoDispose<Map<String, FoodUsage>>((ref) {
  return ref.watch(mealRepositoryProvider).watchFoodUsage();
});

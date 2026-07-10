import 'food.dart';

/// Aggregated usage of one food across the recent meal history: when it was
/// last logged, how many times, and the quantity used most recently. Drives
/// suggestion ranking and the grams prefill in the add-entry sheet.
class FoodUsage {
  const FoodUsage({
    required this.lastUsedAt,
    required this.useCount,
    required this.lastGrams,
  });

  final DateTime lastUsedAt;
  final int useCount;
  final double lastGrams;
}

/// How many most-recently-logged foods are promoted to the top of the
/// suggestion list and shown as quick-pick chips in the add-entry sheet.
const recentFoodsCount = 6;

/// The [recentFoodsCount] most recently logged foods, newest first.
List<Food> recentFoodsByUsage(List<Food> foods, Map<String, FoodUsage> usage) {
  final used = foods.where((f) => usage.containsKey(f.clientId)).toList()
    ..sort((a, b) => usage[b.clientId]!.lastUsedAt.compareTo(usage[a.clientId]!.lastUsedAt));
  return used.take(recentFoodsCount).toList();
}

/// Orders [foods] for suggestion lists: recents first (see
/// [recentFoodsByUsage]), then repeatedly-logged foods by frequency, then
/// the rest in the incoming (alphabetical) order.
List<Food> rankFoodsByUsage(List<Food> foods, Map<String, FoodUsage> usage) {
  if (usage.isEmpty) return foods;

  final recents = recentFoodsByUsage(foods, usage);
  final promoted = recents.map((f) => f.clientId).toSet();

  final frequents = foods
      .where((f) => !promoted.contains(f.clientId) && (usage[f.clientId]?.useCount ?? 0) >= 2)
      .toList()
    ..sort((a, b) {
      final ua = usage[a.clientId]!;
      final ub = usage[b.clientId]!;
      final byCount = ub.useCount.compareTo(ua.useCount);
      return byCount != 0 ? byCount : ub.lastUsedAt.compareTo(ua.lastUsedAt);
    });
  promoted.addAll(frequents.map((f) => f.clientId));

  return [
    ...recents,
    ...frequents,
    ...foods.where((f) => !promoted.contains(f.clientId)),
  ];
}

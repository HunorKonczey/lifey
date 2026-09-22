/// How sure the model is about one item — mirrors the backend's
/// `EstimationConfidence`.
enum EstimateConfidence { high, medium, low }

/// One recognized food from `POST /meals/estimate`. Calories and macros are
/// for [grams] (the estimated portion), not per 100 g
/// (docs/23-ai-calorie-estimation-plan.md).
class EstimatedItem {
  const EstimatedItem({
    required this.name,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.confidence,
  });

  final String name;
  final double grams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final EstimateConfidence confidence;

  factory EstimatedItem.fromJson(Map<String, dynamic> json) {
    return EstimatedItem(
      name: json['name'] as String,
      grams: (json['estimatedGrams'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
      protein: (json['proteinGrams'] as num).toDouble(),
      carbs: (json['carbsGrams'] as num).toDouble(),
      fat: (json['fatGrams'] as num).toDouble(),
      confidence: switch (json['confidence']) {
        'HIGH' => EstimateConfidence.high,
        'MEDIUM' => EstimateConfidence.medium,
        _ => EstimateConfidence.low,
      },
    );
  }
}

/// Result of an AI meal-photo estimate. Transient and online-only — never
/// persisted as-is; confirmed items are saved as ordinary meal entries.
/// An empty [items] list means no food was recognized.
class MealEstimate {
  const MealEstimate({required this.items, this.notes});

  final List<EstimatedItem> items;
  final String? notes;

  factory MealEstimate.fromJson(Map<String, dynamic> json) {
    return MealEstimate(
      items: (json['items'] as List<dynamic>)
          .map((e) => EstimatedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
    );
  }
}

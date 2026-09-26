import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/meal.dart';

/// The icon and tint of a meal type — breakfast in the carbs colour and snack
/// in protein green as the canvas draws them; lunch and dinner take the two
/// remaining data colours so the four rows stay tellable apart.
(IconData, Color) mealTypeStyle(BuildContext context, MealType type) {
  final mc = context.metricColors;
  return switch (type) {
    MealType.breakfast => (Icons.bakery_dining_rounded, mc.carbs),
    MealType.lunch => (Icons.lunch_dining_rounded, mc.calories),
    MealType.dinner => (Icons.dinner_dining_rounded, mc.fat),
    MealType.snack => (Icons.apple_rounded, mc.protein),
  };
}

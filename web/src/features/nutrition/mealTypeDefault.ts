import type { MealType } from "./types";

/**
 * A sensible default meal type for "now", used wherever a meal is logged
 * without a meal-type section to take it from (LogRecipeDialog, and
 * AddMealEntryDialog opened from the Foods tab — docs/75 §2.7).
 *
 * Note: the hour boundaries differ from mobile's `_mealTypeForHour`
 * (log_meal_screen.dart); aligning them is deferred (docs/75 Non-goals).
 */
export function defaultMealType(now: Date = new Date()): MealType {
  const h = now.getHours();
  if (h < 11) return "BREAKFAST";
  if (h < 15) return "LUNCH";
  if (h < 21) return "DINNER";
  return "SNACK";
}

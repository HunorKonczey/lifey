import type { MealRequest, MealResponse } from "./types";

/**
 * Builds the request to re-create [meal] on [targetDate], preserving its
 * original time-of-day, meal type and name — used by both single-meal
 * duplication and "copy a previous day". Landing on the target day (rather
 * than "now") means offering it from a past day in the date picker still
 * copies onto that day, not onto today.
 */
export function copyMealPayload(meal: MealResponse, targetDate: Date): MealRequest {
  const source = new Date(meal.dateTime);
  const target = new Date(targetDate);
  target.setHours(source.getHours(), source.getMinutes(), source.getSeconds(), 0);
  return {
    dateTime: target.toISOString(),
    mealType: meal.mealType,
    name: meal.name,
    entries: meal.entries.map((e) => ({ foodId: e.foodId, quantityInGrams: e.quantityInGrams })),
  };
}

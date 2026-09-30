import type { MealRequest, MealResponse, MealType } from "./types";

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

/** The meal a dashboard "copy yesterday's …" button would copy right now (W1.3). */
export interface CopySuggestion {
  mealType: MealType;
  source: MealResponse;
}

/** The meal type the clock points at: before 10:30 breakfast, before 15:00
 *  lunch, before 17:30 snack, otherwise dinner. */
export function mealTypeForClock(now: Date): MealType {
  const minutes = now.getHours() * 60 + now.getMinutes();
  if (minutes < 10 * 60 + 30) return "BREAKFAST";
  if (minutes < 15 * 60) return "LUNCH";
  if (minutes < 17 * 60 + 30) return "SNACK";
  return "DINNER";
}

function sameLocalDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

/**
 * Offers to copy yesterday's meal of the type the clock points at — but only
 * when today has no entry of that type yet and yesterday had one (the latest,
 * if it had several); otherwise null, and the button stays hidden.
 */
export function suggestCopy(meals: MealResponse[], now: Date): CopySuggestion | null {
  const mealType = mealTypeForClock(now);
  const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);

  const ofType = meals.filter((m) => m.mealType === mealType);
  if (ofType.some((m) => sameLocalDay(new Date(m.dateTime), now))) return null;

  const yesterdays = ofType
    .filter((m) => sameLocalDay(new Date(m.dateTime), yesterday))
    .sort((a, b) => new Date(b.dateTime).getTime() - new Date(a.dateTime).getTime());
  return yesterdays.length > 0 ? { mealType, source: yesterdays[0] } : null;
}

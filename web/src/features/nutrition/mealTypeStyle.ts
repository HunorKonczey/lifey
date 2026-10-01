import type { MealType } from "./types";

/** Breakfast → Lunch → Snack → Dinner, the order the canvas lists the day in. */
export const MEAL_TYPE_ORDER: MealType[] = ["BREAKFAST", "LUNCH", "SNACK", "DINNER"];

/** Each meal type's icon and tint (W2.3, client-004): breakfast carbs gold, lunch protein
 *  green, snack kcal orange, dinner fat violet — the metric tokens, so both themes are covered. */
export const MEAL_TYPE_STYLE: Record<MealType, { icon: string; color: string }> = {
  BREAKFAST: { icon: "bakery_dining", color: "var(--m-carbs)" },
  LUNCH: { icon: "lunch_dining", color: "var(--m-protein)" },
  SNACK: { icon: "icecream", color: "var(--m-kcal)" },
  DINNER: { icon: "dinner_dining", color: "var(--m-fat)" },
};

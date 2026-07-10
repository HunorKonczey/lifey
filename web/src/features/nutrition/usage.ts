import type { FoodResponse, MealResponse } from "./types";

/** Aggregated usage of one food across recent meal history. */
export interface FoodUsage {
  lastUsedAt: number; // epoch ms
  useCount: number;
  lastGrams: number;
}

/** How far back meal history counts toward usage, in days. */
const USAGE_WINDOW_DAYS = 90;

/** How many most-recently-logged foods count as "recent". */
export const RECENT_FOODS_COUNT = 6;

/** Computes per-food usage stats from meal history, keyed by food id. */
export function computeFoodUsage(meals: MealResponse[]): Map<number, FoodUsage> {
  const cutoff = Date.now() - USAGE_WINDOW_DAYS * 24 * 60 * 60 * 1000;
  const usage = new Map<number, FoodUsage>();
  for (const meal of meals) {
    const mealTime = new Date(meal.dateTime).getTime();
    if (mealTime < cutoff) continue;
    for (const entry of meal.entries) {
      const prev = usage.get(entry.foodId);
      const isNewest = !prev || mealTime > prev.lastUsedAt;
      usage.set(entry.foodId, {
        lastUsedAt: isNewest ? mealTime : prev.lastUsedAt,
        useCount: (prev?.useCount ?? 0) + 1,
        lastGrams: isNewest ? entry.quantityInGrams : prev.lastGrams,
      });
    }
  }
  return usage;
}

/** The [RECENT_FOODS_COUNT] most recently logged foods, newest first. */
export function recentFoodsByUsage(
  foods: FoodResponse[],
  usage: Map<number, FoodUsage>,
): FoodResponse[] {
  const used = foods.filter((f) => usage.has(f.id));
  used.sort((a, b) => usage.get(b.id)!.lastUsedAt - usage.get(a.id)!.lastUsedAt);
  return used.slice(0, RECENT_FOODS_COUNT);
}

/**
 * Orders [foods] for suggestion lists: recents first (see
 * {@link recentFoodsByUsage}), then repeatedly-logged foods by frequency,
 * then the rest in the incoming order.
 */
export function rankFoodsByUsage(
  foods: FoodResponse[],
  usage: Map<number, FoodUsage>,
): FoodResponse[] {
  if (usage.size === 0) return foods;

  const recents = recentFoodsByUsage(foods, usage);
  const promoted = new Set(recents.map((f) => f.id));

  const frequents = foods
    .filter((f) => !promoted.has(f.id) && (usage.get(f.id)?.useCount ?? 0) >= 2)
    .sort((a, b) => {
      const ua = usage.get(a.id)!;
      const ub = usage.get(b.id)!;
      return ub.useCount - ua.useCount || ub.lastUsedAt - ua.lastUsedAt;
    });
  frequents.forEach((f) => promoted.add(f.id));

  return [...recents, ...frequents, ...foods.filter((f) => !promoted.has(f.id))];
}

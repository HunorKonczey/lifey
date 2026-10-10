import type { FoodResponse, MealEntryResponse, MealResponse } from "./types";

/**
 * A meal's or a day's fibre and sugars (LIF-145). A food can have no figure ("not known" is not 0), so a total is the sum of
 * what is known: `null` when no entry has one (nothing to show), and `partial` when only some do - the line then says so
 * rather than passing a lower number off as the whole.
 */
export interface FiberSugarTotals {
  fiber: number | null;
  sugar: number | null;
  partial: boolean;
}

function sumKnown(values: Array<number | null | undefined>): number | null {
  const known = values.filter((v): v is number => typeof v === "number");
  return known.length === 0 ? null : known.reduce((s, v) => s + v, 0);
}

export function fiberSugarOfEntries(entries: readonly MealEntryResponse[]): FiberSugarTotals {
  const fiber = sumKnown(entries.map((e) => e.fiber));
  const sugar = sumKnown(entries.map((e) => e.sugar));
  const partial = entries.some((e) => e.fiber == null || e.sugar == null) && (fiber != null || sugar != null);
  return { fiber, sugar, partial };
}

export function fiberSugarOfMeals(meals: readonly MealResponse[]): FiberSugarTotals {
  return fiberSugarOfEntries(meals.flatMap((m) => m.entries));
}

/** `totals` scaled by `factor` (a recipe's servings, a portion): the known parts scale, the partial flag stays. */
export function scaleFiberSugar(totals: FiberSugarTotals, factor: number): FiberSugarTotals {
  return {
    fiber: totals.fiber == null ? null : totals.fiber * factor,
    sugar: totals.sugar == null ? null : totals.sugar * factor,
    partial: totals.partial,
  };
}

/**
 * The fibre and sugars of a recipe's ingredients (LIF-150). The recipe API carries only kcal and protein per ingredient, so
 * - like carbs and fat - they come from the food each ingredient points at (per 100 g x its grams). An ingredient whose food is
 * not in `foodsById` (deleted, not loaded) counts as not known, so the total is partial rather than a silently low number.
 * `gramsOf` overrides the amount of an ingredient (the log dialog's per-portion grams); it defaults to the recipe's own.
 */
export function recipeFiberSugar<T extends { foodId: number; quantityInGrams: number }>(
  ingredients: readonly T[],
  foodsById: ReadonlyMap<number, Pick<FoodResponse, "fiberPer100g" | "sugarPer100g">>,
  gramsOf: (ingredient: T, index: number) => number = (i) => i.quantityInGrams,
): FiberSugarTotals {
  const known = (per100g: number | null | undefined, grams: number) => (typeof per100g === "number" ? (per100g * grams) / 100 : null);
  const parts = ingredients.map((ingredient, index) => {
    const food = foodsById.get(ingredient.foodId);
    const grams = gramsOf(ingredient, index);
    return { fiber: known(food?.fiberPer100g, grams), sugar: known(food?.sugarPer100g, grams) };
  });
  const fiber = sumKnown(parts.map((p) => p.fiber));
  const sugar = sumKnown(parts.map((p) => p.sugar));
  const partial = parts.some((p) => p.fiber == null || p.sugar == null) && (fiber != null || sugar != null);
  return { fiber, sugar, partial };
}

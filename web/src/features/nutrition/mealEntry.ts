import type { MealEntryRequest, MealEntryResponse } from "./types";

/**
 * The request form of a stored meal entry - the **only** place a response entry becomes a request entry (docs/88 §2.3).
 *
 * A meal update replaces all of its entries, so an entry sent without `recipeId` loses the recipe it was added as part
 * of, with no error and nothing to see until a count or a group is missing weeks later. Every writer that rebuilds
 * entries from stored ones (edit, copy, copy a day, add to a meal, remove a row) goes through here, so none of them
 * can forget it. `quantityInGrams` is the one thing a caller may change.
 */
export function entryRequestOf(entry: MealEntryResponse, quantityInGrams: number = entry.quantityInGrams): MealEntryRequest {
  return entry.recipeId != null
    ? { foodId: entry.foodId, quantityInGrams, recipeId: entry.recipeId }
    : { foodId: entry.foodId, quantityInGrams };
}

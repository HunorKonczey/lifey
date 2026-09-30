import type { MealEntryResponse } from "./types";

/** A quantity as the edit drawer shows and accepts it: one decimal ("166,7 g", never "166.68"). */
export const round1 = (n: number): number => Math.round(n * 10) / 10;

/**
 * Whether the drawer holds a real change. `edits[i]` is `null` for a row the
 * user never touched; an edited row counts only if it differs from what the
 * drawer *showed* (the stored quantity at one decimal) — typing the same number
 * back, or 135,2 into a row stored as 135.18…, is not a change.
 */
export function isMealDirty(entries: MealEntryResponse[], edits: (number | null)[]): boolean {
  return edits.some((v, i) => v != null && v !== round1(entries[i].quantityInGrams));
}

/** The entries to save: edited rows with their new quantity, the rest exactly as stored. */
export function editedEntries(
  entries: MealEntryResponse[],
  edits: (number | null)[],
): { foodId: number; quantityInGrams: number }[] {
  return entries.map((e, i) => ({
    foodId: e.foodId,
    quantityInGrams: edits[i] != null && edits[i] !== round1(e.quantityInGrams) ? (edits[i] as number) : e.quantityInGrams,
  }));
}

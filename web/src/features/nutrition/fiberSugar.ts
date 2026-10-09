import type { MealEntryResponse, MealResponse } from "./types";

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

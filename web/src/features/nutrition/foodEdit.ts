import type { FoodRequest, FoodResponse } from "./types";

/** The editor's numbers show at most two decimals — salt and spices need the second. */
export const FOOD_DECIMALS = 2;

export interface FoodFields {
  name: string;
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
  /** Fibre and sugars per 100 g as typed (LIF-145): empty = not known, which is not 0. */
  fiber: string;
  sugar: string;
  barcode: string;
}

export const EMPTY_FOOD: FoodFields = { name: "", kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: "", sugar: "", barcode: "" };

export const MAX_GRAMS_PER_100G = 100;

/**
 * An optional grams-per-100-g text: empty = not known (`null`), a number from 0 to 100 (a comma or a point), else `"invalid"`.
 * The backend refuses a negative; more than 100 g in 100 g is a typo.
 */
export function parseOptionalGrams(text: string): number | null | "invalid" {
  const t = text.trim().replace(",", ".");
  if (t === "") return null;
  if (!/^\d+(\.\d+)?$/.test(t)) return "invalid";
  const value = Number(t);
  return value <= MAX_GRAMS_PER_100G ? Math.round(value * 100) / 100 : "invalid";
}

/** A stored figure as the editor's text: empty for an unknown one. */
export function gramsText(value: number | null | undefined): string {
  return value == null ? "" : String(Math.round(value * 100) / 100);
}

const NUMBER_KEYS = ["kcal", "protein", "carbs", "fat"] as const;

function round(value: number): number {
  const f = 10 ** FOOD_DECIMALS;
  return Math.round(value * f) / f;
}

/** What the editor opens with: a stored food as it is (unrounded), or a prefill over an empty form. */
export function fieldsFromFood(food: FoodResponse | null, prefill?: Partial<FoodResponse>): FoodFields {
  const src = food ?? prefill;
  if (!src) return EMPTY_FOOD;
  return {
    name: src.name ?? "",
    kcal: src.caloriesPer100g ?? 0,
    protein: src.proteinPer100g ?? 0,
    carbs: src.carbsPer100g ?? 0,
    fat: src.fatPer100g ?? 0,
    fiber: gramsText(src.fiberPer100g),
    sugar: gramsText(src.sugarPer100g),
    barcode: src.barcode ?? "",
  };
}

/**
 * Has anything really changed? A number counts as changed only if it differs from
 * the stored one *at the two decimals the field shows* — focusing and leaving a
 * field re-commits its text, which would otherwise turn a stored 13.3333 into a
 * "change" the user never made.
 */
export function isFoodDirty(current: FoodFields, original: FoodFields): boolean {
  if (current.name.trim() !== original.name.trim()) return true;
  if (current.barcode.trim() !== original.barcode.trim()) return true;
  if (current.fiber.trim() !== original.fiber.trim() || current.sugar.trim() !== original.sugar.trim()) return true;
  return NUMBER_KEYS.some((k) => round(current[k]) !== round(original[k]));
}

/**
 * The request to save: edited fields as typed, untouched numbers exactly as stored
 * (never their rounded copy). `hidden` is carried over from the stored food — the
 * editor has no control for it (hidden foods aren't listed, so none is ever edited here).
 */
export function foodRequest(current: FoodFields, original: FoodFields, hidden: boolean): FoodRequest {
  const pick = (k: (typeof NUMBER_KEYS)[number]) => (round(current[k]) === round(original[k]) ? original[k] : current[k]);
  const barcode = current.barcode.trim();
  const fiber = parseOptionalGrams(current.fiber);
  const sugar = parseOptionalGrams(current.sugar);
  return {
    name: current.name.trim(),
    caloriesPer100g: pick("kcal"),
    proteinPer100g: pick("protein"),
    carbsPer100g: pick("carbs"),
    fatPer100g: pick("fat"),
    // Not known = left out, which the server stores as not known (an unparseable text never gets here: the editor blocks Save).
    ...(typeof fiber === "number" ? { fiberPer100g: fiber } : {}),
    ...(typeof sugar === "number" ? { sugarPer100g: sugar } : {}),
    barcode: barcode === "" ? null : barcode,
    hidden,
  };
}

/** A name for a duplicate that no food of the user's has yet: "Oats (copy)", then "Oats (copy 2)", … */
export function duplicateName(name: string, taken: string[], copyWord: string): string {
  const used = new Set(taken.map((n) => n.trim().toLowerCase()));
  const base = name.trim();
  let candidate = `${base} (${copyWord})`;
  for (let n = 2; used.has(candidate.toLowerCase()); n++) candidate = `${base} (${copyWord} ${n})`;
  return candidate;
}

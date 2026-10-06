import { parseLocaleNumber } from "@/components/ds/field/numberFormat";
import type { Macros } from "./recipeMacros";

/** The "enter macros" form as typed — strings, so an empty field stays empty. */
export interface MacroDraft {
  name: string;
  /** How much the entered totals are for; empty = 100 g. */
  grams: string;
  calories: string;
  protein: string;
  carbs: string;
  fat: string;
}

export const EMPTY_MACRO_DRAFT: MacroDraft = { name: "", grams: "", calories: "", protein: "", carbs: "", fat: "" };

export interface ParsedMacroEntry {
  name: string;
  grams: number;
  /** What was typed: the totals of the whole portion. */
  totals: Macros;
}

/** A non-negative number from a field; `fallback` when it is empty, `null` when it is not a number. */
function amount(text: string, fallback: number | null): number | null {
  if (text.trim() === "") return fallback;
  const n = parseLocaleNumber(text);
  return n !== null && n >= 0 ? n : null;
}

/**
 * The draft as numbers, or `null` while it cannot be saved: calories are
 * required, protein / carbs / fat default to 0, the quantity to 100 g (never
 * below 1 g), and anything that is not a non-negative number blocks it.
 */
export function parseMacroDraft(draft: MacroDraft): ParsedMacroEntry | null {
  const calories = amount(draft.calories, null);
  const protein = amount(draft.protein, 0);
  const carbs = amount(draft.carbs, 0);
  const fat = amount(draft.fat, 0);
  const grams = amount(draft.grams, 100);
  if (calories === null || protein === null || carbs === null || fat === null || grams === null) return null;
  return { name: draft.name.trim(), grams: Math.max(1, grams), totals: { calories, protein, carbs, fat } };
}

/** Back to per 100 g, so that the stored food × `grams` / 100 gives the typed totals again. */
export function per100g(totals: Macros, grams: number): Macros {
  const k = 100 / Math.max(grams, 1);
  return { calories: totals.calories * k, protein: totals.protein * k, carbs: totals.carbs * k, fat: totals.fat * k };
}

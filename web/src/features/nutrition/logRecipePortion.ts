import type { MealEntryRequest, RecipeIngredientResponse } from "./types";

/**
 * Pure logic behind LogRecipeDialog's adjustable ingredient amounts: each
 * ingredient's per-portion grams default to the recipe amount divided by the
 * portion divisor, and the user can override individual amounts (keyed by
 * ingredient index) with what they actually ate. An override of 0 leaves the
 * ingredient out. Overrides survive divisor changes — an explicit "this is
 * what I ate" beats a recalculated default.
 */
export type GramsOverrides = Record<number, string>;

export const round2 = (n: number) => Math.round(n * 100) / 100;

/** Divisor-derived per-portion grams for one ingredient. */
export function defaultGrams(ingredient: RecipeIngredientResponse, divisor: number): number {
  return round2(ingredient.quantityInGrams / divisor);
}

/** Parse a user-typed amount; empty, invalid or negative input counts as 0. */
export function parseGrams(text: string): number {
  const n = parseFloat(text.replace(",", "."));
  return Number.isFinite(n) && n >= 0 ? n : 0;
}

/** Grams actually being logged for one ingredient: override if present, else the default. */
export function gramsFor(
  ingredient: RecipeIngredientResponse,
  index: number,
  divisor: number,
  overrides: GramsOverrides,
): number {
  const raw = overrides[index];
  return raw === undefined ? defaultGrams(ingredient, divisor) : parseGrams(raw);
}

/** Effective kcal/protein totals of the logged portion, overrides applied. */
export function scaledTotals(
  ingredients: RecipeIngredientResponse[],
  divisor: number,
  overrides: GramsOverrides,
): { calories: number; protein: number } {
  let calories = 0;
  let protein = 0;
  ingredients.forEach((ingredient, i) => {
    if (ingredient.quantityInGrams <= 0) return;
    const ratio = gramsFor(ingredient, i, divisor, overrides) / ingredient.quantityInGrams;
    calories += ingredient.calories * ratio;
    protein += ingredient.protein * ratio;
  });
  return { calories, protein };
}

/** Meal entries for the logged portion; zero-gram ingredients are left out. */
export function buildEntries(
  ingredients: RecipeIngredientResponse[],
  divisor: number,
  overrides: GramsOverrides,
): MealEntryRequest[] {
  return ingredients.flatMap((ingredient, i) => {
    const grams = round2(gramsFor(ingredient, i, divisor, overrides));
    return grams > 0 ? [{ foodId: ingredient.foodId, quantityInGrams: grams }] : [];
  });
}

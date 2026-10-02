import type { FoodResponse, RecipeResponse } from "./types";

export interface Macros {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

/**
 * A recipe's totals (W2.6 / W2.11). The recipe API carries only kcal and
 * protein per ingredient, so carbs and fat are worked out from the foods the
 * ingredients point at (per 100 g × grams); an ingredient whose food isn't in
 * `foodsById` (deleted, not loaded) contributes kcal and protein only.
 */
export function recipeTotals(recipe: RecipeResponse, foodsById: ReadonlyMap<number, FoodResponse>): Macros {
  let calories = 0;
  let protein = 0;
  let carbs = 0;
  let fat = 0;
  for (const ing of recipe.ingredients) {
    calories += ing.calories;
    protein += ing.protein;
    const food = foodsById.get(ing.foodId);
    if (food) {
      carbs += ((food.carbsPer100g ?? 0) * ing.quantityInGrams) / 100;
      fat += ((food.fatPer100g ?? 0) * ing.quantityInGrams) / 100;
    }
  }
  return { calories, protein, carbs, fat };
}

/** `portions` servings' worth of a recipe. */
export function recipePortion(recipe: RecipeResponse, foodsById: ReadonlyMap<number, FoodResponse>, portions: number): Macros {
  const t = recipeTotals(recipe, foodsById);
  const k = portions / Math.max(recipe.servings, 1);
  return { calories: t.calories * k, protein: t.protein * k, carbs: t.carbs * k, fat: t.fat * k };
}

/** A food's macros for `grams`. */
export function foodPortion(food: FoodResponse, grams: number): Macros {
  const k = grams / 100;
  return {
    calories: food.caloriesPer100g * k,
    protein: food.proteinPer100g * k,
    carbs: (food.carbsPer100g ?? 0) * k,
    fat: (food.fatPer100g ?? 0) * k,
  };
}

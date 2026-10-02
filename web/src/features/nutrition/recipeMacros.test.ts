import { describe, expect, it } from "vitest";
import { foodPortion, recipePortion, recipeTotals } from "./recipeMacros";
import type { FoodResponse, RecipeResponse } from "./types";

const food = (id: number, carbs: number | null, fat: number | null): FoodResponse => ({
  id,
  name: `f${id}`,
  caloriesPer100g: 100,
  proteinPer100g: 10,
  carbsPer100g: carbs,
  fatPer100g: fat,
  barcode: null as unknown as string,
  hidden: false,
});

const recipe: RecipeResponse = {
  id: 1,
  name: "Bowl",
  description: null,
  favorite: false,
  servings: 4,
  imageUpdatedAt: null,
  ingredients: [
    { foodId: 1, foodName: "f1", quantityInGrams: 200, calories: 200, protein: 20 },
    { foodId: 2, foodName: "f2", quantityInGrams: 100, calories: 100, protein: 10 },
    { foodId: 3, foodName: "gone", quantityInGrams: 50, calories: 40, protein: 2 },
  ],
};
const foods = new Map([
  [1, food(1, 50, 10)],
  [2, food(2, 20, null)],
]);

describe("recipeTotals", () => {
  it("sums kcal and protein from the ingredients and carbs / fat from their foods", () => {
    const t = recipeTotals(recipe, foods);
    expect(t.calories).toBe(340);
    expect(t.protein).toBe(32);
    expect(t.carbs).toBe(120); // 200 g × 50 + 100 g × 20 per 100 g
    expect(t.fat).toBe(20); // 200 g × 10; a null fat counts as 0
  });

  it("an ingredient whose food is unknown adds kcal and protein only", () => {
    expect(recipeTotals(recipe, new Map())).toEqual({ calories: 340, protein: 32, carbs: 0, fat: 0 });
  });
});

describe("recipePortion", () => {
  it("scales the whole dish by portions / servings", () => {
    const p = recipePortion(recipe, foods, 1); // 1 of 4 servings
    expect(p.calories).toBe(85);
    expect(p.carbs).toBe(30);
    expect(recipePortion(recipe, foods, 2).calories).toBe(170);
    expect(recipePortion(recipe, foods, 0.5).calories).toBe(42.5);
  });
});

describe("foodPortion", () => {
  it("is per-100 g values times grams / 100, with a null macro as 0", () => {
    const p = foodPortion(food(1, 5.4, null), 150);
    expect(p.calories).toBe(150);
    expect(p.protein).toBe(15);
    expect(p.carbs).toBeCloseTo(8.1, 6);
    expect(p.fat).toBe(0);
  });
});

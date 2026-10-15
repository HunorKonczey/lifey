import { describe, expect, it } from "vitest";
import { entryRequestOf } from "./mealEntry";
import type { MealEntryResponse } from "./types";

const entry = (overrides: Partial<MealEntryResponse> = {}): MealEntryResponse => ({
  foodId: 3,
  foodName: "Beans",
  quantityInGrams: 120.5,
  calories: 100,
  protein: 6,
  carbs: 18,
  fat: 1,
  ...overrides,
});

describe("entryRequestOf", () => {
  it("keeps the food and the quantity exactly as stored", () => {
    expect(entryRequestOf(entry())).toEqual({ foodId: 3, quantityInGrams: 120.5 });
  });

  it("carries the recipe the entry was added as part of (docs/88 §2.3)", () => {
    expect(entryRequestOf(entry({ recipeId: 7, recipeName: "Chilli" }))).toEqual({
      foodId: 3,
      quantityInGrams: 120.5,
      recipeId: 7,
    });
  });

  it("sends no recipe for an entry that has none, null or absent", () => {
    expect(entryRequestOf(entry({ recipeId: null }))).not.toHaveProperty("recipeId");
    expect(entryRequestOf(entry())).not.toHaveProperty("recipeId");
  });

  it("changes only the quantity when asked to", () => {
    expect(entryRequestOf(entry({ recipeId: 7 }), 60)).toEqual({ foodId: 3, quantityInGrams: 60, recipeId: 7 });
  });
});

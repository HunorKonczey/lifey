import { describe, expect, it } from "vitest";
import { buildEntries, defaultGrams, gramsFor, parseGrams, scaledTotals } from "./logRecipePortion";
import type { RecipeIngredientResponse } from "./types";

const chicken: RecipeIngredientResponse = {
  foodId: 1, foodName: "Chicken", quantityInGrams: 300, calories: 600, protein: 60,
};
const rice: RecipeIngredientResponse = {
  foodId: 2, foodName: "Rice", quantityInGrams: 200, calories: 260, protein: 5,
};
const ingredients = [chicken, rice];

describe("parseGrams", () => {
  it("accepts a decimal comma", () => {
    expect(parseGrams("66,67")).toBe(66.67);
  });

  it("treats empty, invalid and negative input as 0", () => {
    expect(parseGrams("")).toBe(0);
    expect(parseGrams("abc")).toBe(0);
    expect(parseGrams("-5")).toBe(0);
  });
});

describe("defaultGrams", () => {
  it("divides the recipe amount by the divisor, rounded to 2 decimals", () => {
    expect(defaultGrams(chicken, 2)).toBe(150);
    expect(defaultGrams(rice, 3)).toBe(66.67);
  });
});

describe("gramsFor", () => {
  it("prefers the override and keeps it across divisor changes", () => {
    expect(gramsFor(chicken, 0, 2, { 0: "180" })).toBe(180);
    expect(gramsFor(chicken, 0, 3, { 0: "180" })).toBe(180);
  });

  it("falls back to the divisor-derived default without an override", () => {
    expect(gramsFor(rice, 1, 2, { 0: "180" })).toBe(100);
  });
});

describe("scaledTotals", () => {
  it("sums macros of the divided portion when nothing is overridden", () => {
    const { calories, protein } = scaledTotals(ingredients, 2, {});
    expect(calories).toBeCloseTo(430); // (600 + 260) / 2
    expect(protein).toBeCloseTo(32.5);
  });

  it("scales an overridden ingredient by its actual grams", () => {
    const { calories } = scaledTotals(ingredients, 2, { 0: "180" });
    expect(calories).toBeCloseTo(600 * (180 / 300) + 130);
  });

  it("skips a zero-quantity ingredient instead of dividing by zero", () => {
    const weird: RecipeIngredientResponse = { ...rice, quantityInGrams: 0 };
    const { calories } = scaledTotals([chicken, weird], 1, {});
    expect(calories).toBe(600);
  });
});

describe("buildEntries", () => {
  it("builds divided entries by default", () => {
    expect(buildEntries(ingredients, 2, {})).toEqual([
      { foodId: 1, quantityInGrams: 150 },
      { foodId: 2, quantityInGrams: 100 },
    ]);
  });

  it("uses overrides and leaves out zero-gram ingredients", () => {
    expect(buildEntries(ingredients, 2, { 0: "180", 1: "0" })).toEqual([
      { foodId: 1, quantityInGrams: 180 },
    ]);
  });

  it("returns no entries when everything is zeroed out", () => {
    expect(buildEntries(ingredients, 1, { 0: "0", 1: "" })).toEqual([]);
  });
});

import { describe, expect, it } from "vitest";
import { fiberSugarOfEntries, fiberSugarOfMeals } from "./fiberSugar";
import type { MealEntryResponse, MealResponse } from "./types";

const entry = (fiber?: number | null, sugar?: number | null): MealEntryResponse => ({
  foodId: 1,
  foodName: "Oats",
  quantityInGrams: 100,
  calories: 100,
  protein: 5,
  carbs: 10,
  fat: 2,
  fiber,
  sugar,
});

describe("fiberSugarOfEntries", () => {
  it("sums what is known; complete figures are not partial", () => {
    expect(fiberSugarOfEntries([entry(4, 1), entry(6, 2.5)])).toEqual({ fiber: 10, sugar: 3.5, partial: false });
  });

  it("is null, not 0, when no food has a figure - there is nothing to show", () => {
    expect(fiberSugarOfEntries([entry(null, null), entry()])).toEqual({ fiber: null, sugar: null, partial: false });
    expect(fiberSugarOfEntries([])).toEqual({ fiber: null, sugar: null, partial: false });
  });

  it("marks a sum over only some of the foods as partial, and counts a known 0", () => {
    expect(fiberSugarOfEntries([entry(4, 1), entry(null, null)])).toEqual({ fiber: 4, sugar: 1, partial: true });
    expect(fiberSugarOfEntries([entry(0, 0)])).toEqual({ fiber: 0, sugar: 0, partial: false });
  });

  it("fibre known but sugar not (or the other way) is partial, with the unknown one null", () => {
    expect(fiberSugarOfEntries([entry(4, null)])).toEqual({ fiber: 4, sugar: null, partial: true });
  });
});

describe("fiberSugarOfMeals", () => {
  it("adds up across the day's meals", () => {
    const meal = (entries: MealEntryResponse[]): MealResponse => ({ id: 1, dateTime: "2026-10-09T07:00:00Z", mealType: "BREAKFAST", name: null, entries });
    expect(fiberSugarOfMeals([meal([entry(4, 1)]), meal([entry(6, 2)])])).toEqual({ fiber: 10, sugar: 3, partial: false });
  });
});

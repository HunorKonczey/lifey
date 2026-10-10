import { describe, expect, it } from "vitest";
import { fiberSugarOfEntries, fiberSugarOfMeals, recipeFiberSugar, scaleFiberSugar } from "./fiberSugar";
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

describe("recipeFiberSugar (LIF-150)", () => {
  const foods = new Map([
    [1, { fiberPer100g: 10, sugarPer100g: 1 }],
    [2, { fiberPer100g: 2.4, sugarPer100g: 10 }],
    [3, { fiberPer100g: null, sugarPer100g: null }],
    [4, { fiberPer100g: 4, sugarPer100g: null }],
  ]);
  const ing = (foodId: number, quantityInGrams: number) => ({ foodId, quantityInGrams });

  it("sums each ingredient's food figure scaled to its grams", () => {
    const t = recipeFiberSugar([ing(1, 50), ing(2, 150)], foods);
    expect(t.fiber).toBeCloseTo(8.6, 9);
    expect(t.sugar).toBeCloseTo(15.5, 9);
    expect(t.partial).toBe(false);
  });

  it("an ingredient whose food has no figure adds nothing and makes the total partial", () => {
    expect(recipeFiberSugar([ing(1, 100), ing(3, 200)], foods)).toEqual({ fiber: 10, sugar: 1, partial: true });
  });

  it("a food that is not loaded counts as not known, not as 0 g of fibre", () => {
    expect(recipeFiberSugar([ing(1, 100), ing(99, 100)], foods)).toEqual({ fiber: 10, sugar: 1, partial: true });
  });

  it("nothing known anywhere: null and not partial", () => {
    expect(recipeFiberSugar([ing(3, 100), ing(99, 100)], foods)).toEqual({ fiber: null, sugar: null, partial: false });
    expect(recipeFiberSugar([], foods)).toEqual({ fiber: null, sugar: null, partial: false });
  });

  it("a food known for fibre only keeps the fibre, leaves sugar null and is partial", () => {
    expect(recipeFiberSugar([ing(4, 100)], foods)).toEqual({ fiber: 4, sugar: null, partial: true });
  });

  it("the grams can be overridden per ingredient (the log dialog's portion), with the ingredient's index", () => {
    const t = recipeFiberSugar([ing(1, 300), ing(2, 300)], foods, (_i, index) => (index === 0 ? 50 : 0));
    expect(t).toEqual({ fiber: 5, sugar: 0.5, partial: false });
  });
});

describe("scaleFiberSugar", () => {
  it("scales the known parts, keeps null and the partial flag", () => {
    expect(scaleFiberSugar({ fiber: 10, sugar: null, partial: true }, 0.5)).toEqual({ fiber: 5, sugar: null, partial: true });
  });
});

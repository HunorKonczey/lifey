import { describe, it, expect } from "vitest";
import { computeFoodUsage, computeRecipeUsage, recentFoodsByUsage, rankFoodsByUsage, RECENT_FOODS_COUNT } from "./usage";
import type { FoodResponse, MealResponse } from "./types";

function food(id: number, name: string): FoodResponse {
  return { id, name, caloriesPer100g: 100, proteinPer100g: 10, carbsPer100g: null, fatPer100g: null, barcode: null, hidden: false };
}

function meal(id: number, daysAgo: number, entries: { foodId: number; grams: number }[]): MealResponse {
  const dateTime = new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000).toISOString();
  return {
    id,
    dateTime,
    mealType: "LUNCH",
    name: null,
    entries: entries.map((e) => ({
      foodId: e.foodId,
      foodName: `food-${e.foodId}`,
      quantityInGrams: e.grams,
      calories: 100,
      protein: 10,
      carbs: 0,
      fat: 0,
    })),
  };
}

describe("computeFoodUsage", () => {
  it("aggregates count, last-used time and last grams per food", () => {
    const meals = [
      meal(1, 2, [{ foodId: 10, grams: 150 }, { foodId: 20, grams: 80 }]),
      meal(2, 1, [{ foodId: 10, grams: 200 }]),
    ];

    const usage = computeFoodUsage(meals);

    expect(usage.size).toBe(2);
    expect(usage.get(10)!.useCount).toBe(2);
    expect(usage.get(10)!.lastGrams).toBe(200);
    expect(usage.get(20)!.useCount).toBe(1);
    expect(usage.get(20)!.lastGrams).toBe(80);
  });

  it("lastGrams comes from the newest meal regardless of array order", () => {
    const meals = [
      meal(1, 0, [{ foodId: 10, grams: 60 }]),
      meal(2, 5, [{ foodId: 10, grams: 90 }]),
    ];

    const usage = computeFoodUsage(meals);

    expect(usage.get(10)!.lastGrams).toBe(60);
  });

  it("ignores meals older than the 90-day window", () => {
    const meals = [
      meal(1, 120, [{ foodId: 10, grams: 100 }]),
      meal(2, 3, [{ foodId: 20, grams: 100 }]),
    ];

    const usage = computeFoodUsage(meals);

    expect([...usage.keys()]).toEqual([20]);
  });

  it("returns an empty map with no meal history", () => {
    expect(computeFoodUsage([]).size).toBe(0);
  });
});

describe("recentFoodsByUsage", () => {
  it(`returns used foods newest first, capped at ${RECENT_FOODS_COUNT}`, () => {
    const foods = Array.from({ length: 10 }, (_, i) => food(i, `f${i}`));
    const meals = Array.from({ length: 8 }, (_, i) => meal(i, i, [{ foodId: i, grams: 100 }]));
    const usage = computeFoodUsage(meals);

    const recents = recentFoodsByUsage(foods, usage);

    expect(recents.map((f) => f.id)).toEqual([0, 1, 2, 3, 4, 5]);
  });

  it("is empty when nothing was ever logged", () => {
    expect(recentFoodsByUsage([food(1, "a")], new Map())).toEqual([]);
  });
});

describe("rankFoodsByUsage", () => {
  it("keeps the incoming order when there is no usage", () => {
    const foods = [food(1, "a"), food(2, "b")];
    expect(rankFoodsByUsage(foods, new Map())).toBe(foods);
  });

  it("orders recents, then frequents by count, then the rest", () => {
    // 8 foods; ids 0..5 are the 6 most recent (recency runs opposite to id
    // order, so a correct ranking must diverge from the incoming order).
    // id 6 was used 5 times but falls outside the recents cap → frequent.
    const foods = Array.from({ length: 8 }, (_, i) => food(i, `f${i}`));
    const meals = [
      ...Array.from({ length: 6 }, (_, i) => meal(i, 5 - i, [{ foodId: i, grams: 100 }])),
      ...Array.from({ length: 5 }, (_, i) => meal(100 + i, 7, [{ foodId: 6, grams: 100 }])),
    ];
    const usage = computeFoodUsage(meals);

    const ranked = rankFoodsByUsage(foods, usage);

    expect(ranked.map((f) => f.id)).toEqual([5, 4, 3, 2, 1, 0, 6, 7]);
  });

  it("demotes a once-used food beyond the recents cap to the alphabetical rest", () => {
    const foods = [food(1, "a"), ...Array.from({ length: 6 }, (_, i) => food(10 + i, `r${i}`)), food(99, "z")];
    const meals = [
      ...Array.from({ length: 6 }, (_, i) => meal(i, i + 1, [{ foodId: 10 + i, grams: 100 }])),
      meal(50, 30, [{ foodId: 99, grams: 100 }]),
    ];
    const usage = computeFoodUsage(meals);

    const ranked = rankFoodsByUsage(foods, usage);

    expect(ranked.map((f) => f.id)).toEqual([10, 11, 12, 13, 14, 15, 1, 99]);
  });

  it("breaks frequency ties by recency", () => {
    const foods = [
      ...Array.from({ length: 6 }, (_, i) => food(i, `r${i}`)),
      food(100, "x"),
      food(101, "y"),
    ];
    const meals = [
      ...Array.from({ length: 6 }, (_, i) => meal(i, i + 1, [{ foodId: i, grams: 100 }])),
      meal(200, 20, [{ foodId: 100, grams: 100 }]),
      meal(201, 21, [{ foodId: 100, grams: 100 }]),
      meal(202, 21, [{ foodId: 100, grams: 100 }]),
      meal(300, 10, [{ foodId: 101, grams: 100 }]),
      meal(301, 11, [{ foodId: 101, grams: 100 }]),
      meal(302, 11, [{ foodId: 101, grams: 100 }]),
    ];
    const usage = computeFoodUsage(meals);

    const ranked = rankFoodsByUsage(foods, usage);

    expect(ranked.slice(6, 8).map((f) => f.id)).toEqual([101, 100]);
  });
});

describe("computeRecipeUsage", () => {
  const tagged = (id: number, daysAgo: number, tags: (number | null)[], name: string | null = null): MealResponse => ({
    ...meal(id, daysAgo, tags.map(() => ({ foodId: 1, grams: 100 }))),
    name,
    entries: tags.map((recipeId, i) => ({
      foodId: i + 1,
      foodName: `food-${i + 1}`,
      quantityInGrams: 100,
      calories: 100,
      protein: 10,
      carbs: 0,
      fat: 0,
      recipeId,
    })),
  });

  it("counts a meal once per recipe, however many of its entries carry the tag", () => {
    const usage = computeRecipeUsage([tagged(1, 2, [10, 10, 10, null])]);

    expect(usage.size).toBe(1);
    expect(usage.get(10)?.useCount).toBe(1);
  });

  it("finds a recipe mixed into a meal with other foods, and counts every recipe of the meal", () => {
    const usage = computeRecipeUsage([tagged(1, 2, [10, null, 11])]);

    expect(usage.get(10)?.useCount).toBe(1);
    expect(usage.get(11)?.useCount).toBe(1);
  });

  it("adds up the meals and keeps the newest date", () => {
    const usage = computeRecipeUsage([tagged(1, 5, [10]), tagged(2, 1, [10]), tagged(3, 2, [11])]);

    expect(usage.get(10)?.useCount).toBe(2);
    expect(usage.get(10)!.lastUsedAt).toBeGreaterThan(Date.now() - 2 * 24 * 60 * 60 * 1000);
    expect(usage.get(11)?.useCount).toBe(1);
  });

  it("does not depend on the meal's name, so a renamed recipe keeps its history", () => {
    const usage = computeRecipeUsage([tagged(1, 2, [10], "The old name")]);

    expect(usage.get(10)?.useCount).toBe(1);
  });

  it("ignores untagged meals - even a named one - and logs older than the 90-day window", () => {
    const usage = computeRecipeUsage([tagged(1, 1, [null, null], "Lentil soup"), tagged(2, 120, [10])]);

    expect(usage.size).toBe(0);
  });
});

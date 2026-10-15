import { describe, expect, it } from "vitest";
import { isRecipeMeal, mealItemRows, recipeMealName } from "./MealCard";
import type { MealEntryResponse, MealResponse } from "../types";

const entry = (foodId: number, name: string, grams: number, kcal: number, recipe?: { id: number; name: string }): MealEntryResponse => ({
  foodId,
  foodName: name,
  quantityInGrams: grams,
  calories: kcal,
  protein: kcal / 10,
  carbs: kcal / 5,
  fat: kcal / 20,
  recipeId: recipe?.id ?? null,
  recipeName: recipe?.name ?? null,
});

const chilli = { id: 7, name: "Chilli" };
const soup = { id: 8, name: "Soup" };

const meal = (entries: MealEntryResponse[], name: string | null = null): MealResponse => ({
  id: 1,
  dateTime: "2026-10-15T12:00:00.000Z",
  mealType: "LUNCH",
  name,
  entries,
});

describe("mealItemRows", () => {
  it("shows each loose food on its own row", () => {
    const rows = mealItemRows(meal([entry(1, "Rice", 100, 130), entry(2, "Salad", 50, 10)]));

    expect(rows.map((r) => r.name)).toEqual(["Rice", "Salad"]);
    expect(rows.map((r) => r.entryIndexes)).toEqual([[0], [1]]);
  });

  it("groups the entries of one recipe into a single row beside the loose foods (docs/88 §2.8)", () => {
    const rows = mealItemRows(
      meal([entry(1, "Beans", 100, 100, chilli), entry(2, "Salad", 50, 10), entry(3, "Beef", 60, 150, chilli), entry(4, "Rice", 50, 65, chilli)]),
    );

    expect(rows.map((r) => r.name)).toEqual(["Chilli", "Salad"]);
    expect(rows[0]).toMatchObject({ grams: 210, kcal: 315, entryIndexes: [0, 2, 3] });
    expect(rows[0].protein).toBeCloseTo(31.5);
    expect(rows[1].entryIndexes).toEqual([1]);
  });

  it("puts the group where its first entry is, and keeps two recipes apart", () => {
    const rows = mealItemRows(meal([entry(1, "Salad", 50, 10), entry(2, "Beans", 100, 100, chilli), entry(3, "Lentils", 80, 90, soup), entry(4, "Beef", 60, 150, chilli)]));

    expect(rows.map((r) => r.name)).toEqual(["Salad", "Chilli", "Soup"]);
    expect(rows[1].entryIndexes).toEqual([1, 3]);
    expect(rows[2].entryIndexes).toEqual([2]);
  });

  it("names a group after the recipe's current name, not the meal's", () => {
    const rows = mealItemRows(meal([entry(1, "Beans", 100, 100, { id: 7, name: "Renamed chilli" }), entry(2, "Salad", 50, 10)], "Chilli"));

    expect(rows[0].name).toBe("Renamed chilli");
  });

  it("a meal that is nothing but one recipe is one row for the whole portion, tagged or not", () => {
    const tagged = meal([entry(1, "Beans", 100, 100, chilli), entry(2, "Beef", 60, 150, chilli)]);
    const legacy = meal([entry(1, "Beans", 100, 100), entry(2, "Beef", 60, 150)], "Chilli");

    for (const m of [tagged, legacy]) {
      const rows = mealItemRows(m);
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ name: "Chilli", grams: 160, kcal: 250, entryIndexes: [0, 1] });
    }
  });
});

describe("recipeMealName", () => {
  it("is the recipe of a meal made only of it, or a legacy named meal; null for anything mixed or plain", () => {
    expect(recipeMealName(meal([entry(1, "Beans", 100, 100, chilli)]))).toBe("Chilli");
    expect(recipeMealName(meal([entry(1, "Beans", 100, 100)], "Chilli"))).toBe("Chilli");
    expect(recipeMealName(meal([entry(1, "Beans", 100, 100, chilli), entry(2, "Salad", 50, 10)]))).toBeNull();
    expect(recipeMealName(meal([entry(1, "Beans", 100, 100, chilli), entry(2, "Lentils", 80, 90, soup)]))).toBeNull();
    expect(recipeMealName(meal([entry(1, "Rice", 100, 130)]))).toBeNull();
    expect(recipeMealName(meal([]))).toBeNull();
  });

  it("does not treat a name over a mixed meal as a recipe meal", () => {
    expect(isRecipeMeal(meal([entry(1, "Beans", 100, 100, chilli), entry(2, "Salad", 50, 10)], "Chilli"))).toBe(false);
  });
});

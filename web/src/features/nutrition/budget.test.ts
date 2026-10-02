import { describe, it, expect } from "vitest";
import { computeRemainingBudget, hasGoal, isOver, remainingAfter, remainingOf, sumMeals } from "./budget";
import type { MealResponse } from "./types";

function meal(calories: number, protein: number): MealResponse {
  return {
    id: 1,
    dateTime: new Date().toISOString(),
    mealType: "LUNCH",
    name: null,
    entries: [{ foodId: 1, foodName: "food", quantityInGrams: 100, calories, protein, carbs: 0, fat: 0 }],
  };
}

describe("sumMeals", () => {
  it("sums calories and protein across all entries in all meals", () => {
    const total = sumMeals([meal(400, 30), meal(250, 15)]);
    expect(total).toEqual({ calories: 650, protein: 45 });
  });

  it("returns zero for no meals", () => {
    expect(sumMeals([])).toEqual({ calories: 0, protein: 0 });
  });
});

describe("computeRemainingBudget / remainingOf / isOver / hasGoal", () => {
  it("no goals set -> both metrics report no goal", () => {
    const budget = computeRemainingBudget(
      { calories: 500, protein: 20 },
      { dailyCalorieGoal: null, dailyProteinGoal: null },
    );

    expect(hasGoal(budget.calories)).toBe(false);
    expect(remainingOf(budget.calories)).toBeNull();
    expect(hasGoal(budget.protein)).toBe(false);
  });

  it("under budget -> positive remaining, not over", () => {
    const budget = computeRemainingBudget(
      { calories: 1460, protein: 90 },
      { dailyCalorieGoal: 2200, dailyProteinGoal: 150 },
    );

    expect(remainingOf(budget.calories)).toBe(740);
    expect(isOver(budget.calories)).toBe(false);
    expect(remainingOf(budget.protein)).toBe(60);
  });

  it("over budget -> negative remaining, isOver true, never clamped", () => {
    const budget = computeRemainingBudget(
      { calories: 2500, protein: 40 },
      { dailyCalorieGoal: 2200, dailyProteinGoal: 150 },
    );

    expect(remainingOf(budget.calories)).toBe(-300);
    expect(isOver(budget.calories)).toBe(true);
  });

  it("only one goal set -> other metric reports no goal", () => {
    const budget = computeRemainingBudget(
      { calories: 500, protein: 40 },
      { dailyCalorieGoal: 2200, dailyProteinGoal: null },
    );

    expect(hasGoal(budget.calories)).toBe(true);
    expect(hasGoal(budget.protein)).toBe(false);
  });
});

describe("remainingAfter", () => {
  const goals = { dailyCalorieGoal: 1900, dailyProteinGoal: 120 };

  it("a new entry is simply subtracted from what is left", () => {
    // 1 041 kcal / 68 g eaten; adding 110 kcal / 15 g
    const r = remainingAfter({ calories: 1041, protein: 68 }, goals, { calories: 110, protein: 15 });
    expect(r).toEqual({ calories: 749, protein: 37 });
  });

  it("editing: the stored version of the entry is taken out first, so an unchanged edit changes nothing", () => {
    const stored = { calories: 110, protein: 15 };
    const consumedWithStored = { calories: 1041, protein: 68 }; // already includes `stored`
    const unchanged = remainingAfter(consumedWithStored, goals, stored, stored);
    expect(unchanged).toEqual({ calories: 1900 - 1041, protein: 120 - 68 });
    // treating the edit as a new entry would double-count it
    const naive = remainingAfter(consumedWithStored, goals, stored);
    expect(naive.calories).toBe(1900 - 1041 - 110);
  });

  it("editing to a bigger amount subtracts only the difference", () => {
    const r = remainingAfter({ calories: 1041, protein: 68 }, goals, { calories: 165, protein: 22 }, { calories: 110, protein: 15 });
    expect(r).toEqual({ calories: 1900 - 1041 - 55, protein: 120 - 68 - 7 });
  });

  it("goes negative when the entry overshoots the goal", () => {
    expect(remainingAfter({ calories: 1800, protein: 110 }, goals, { calories: 300, protein: 25 })).toEqual({
      calories: -200,
      protein: -15,
    });
  });

  it("has no figure for a metric without a goal", () => {
    const r = remainingAfter({ calories: 500, protein: 30 }, { dailyCalorieGoal: null, dailyProteinGoal: 120 }, { calories: 100, protein: 10 });
    expect(r).toEqual({ calories: null, protein: 80 });
    expect(
      remainingAfter({ calories: 0, protein: 0 }, { dailyCalorieGoal: null, dailyProteinGoal: null }, { calories: 1, protein: 1 }),
    ).toEqual({ calories: null, protein: null });
  });
});

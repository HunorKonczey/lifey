import { describe, it, expect } from "vitest";
import { computeRemainingBudget, hasGoal, isOver, remainingOf, sumMeals } from "./budget";
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

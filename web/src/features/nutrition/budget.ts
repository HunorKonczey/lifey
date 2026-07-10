import type { MealResponse } from "./types";

/** One metric's consumed/goal/remaining figures for a day. `goal` is null
 * when the user hasn't set that daily goal — callers should hide the
 * remaining UI for that metric rather than inventing a default. */
export interface BudgetMetric {
  consumed: number;
  goal: number | null;
}

export interface RemainingBudget {
  calories: BudgetMetric;
  protein: BudgetMetric;
}

export function hasGoal(metric: BudgetMetric): boolean {
  return metric.goal != null;
}

/** Positive while under budget, negative once over. Null without a goal. */
export function remainingOf(metric: BudgetMetric): number | null {
  return metric.goal == null ? null : metric.goal - metric.consumed;
}

export function isOver(metric: BudgetMetric): boolean {
  const remaining = remainingOf(metric);
  return remaining != null && remaining < 0;
}

/** Sums calories + protein across a set of meals (e.g. one day's meals). */
export function sumMeals(meals: MealResponse[]): { calories: number; protein: number } {
  return meals.reduce(
    (acc, meal) => {
      for (const entry of meal.entries) {
        acc.calories += entry.calories;
        acc.protein += entry.protein;
      }
      return acc;
    },
    { calories: 0, protein: 0 },
  );
}

export function computeRemainingBudget(
  consumed: { calories: number; protein: number },
  goals: { dailyCalorieGoal: number | null; dailyProteinGoal: number | null },
): RemainingBudget {
  return {
    calories: { consumed: consumed.calories, goal: goals.dailyCalorieGoal },
    protein: { consumed: consumed.protein, goal: goals.dailyProteinGoal },
  };
}

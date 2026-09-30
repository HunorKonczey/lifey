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

export interface Nutrients {
  calories: number;
  protein: number;
}

export interface RemainingAfter {
  /** kcal left of the goal once the entry is in — negative when it would go over; null without a calorie goal. */
  calories: number | null;
  /** Grams of protein still to go after the entry — negative once past the goal; null without a protein goal. */
  protein: number | null;
}

/**
 * What would be left of the day's budget after an entry (W2.6, "Utána marad").
 *
 * `consumed` is the day's total *as stored* — which already includes the stored
 * version of an entry being edited. Pass that stored version as `replaces` so it
 * is taken out before the new one goes in; otherwise the old amount would count
 * twice and an edit that changes nothing would appear to eat into the budget.
 * A brand-new entry has no `replaces`.
 */
export function remainingAfter(
  consumed: Nutrients,
  goals: { dailyCalorieGoal: number | null; dailyProteinGoal: number | null },
  add: Nutrients,
  replaces?: Nutrients,
): RemainingAfter {
  const calories = consumed.calories - (replaces?.calories ?? 0) + add.calories;
  const protein = consumed.protein - (replaces?.protein ?? 0) + add.protein;
  return {
    calories: goals.dailyCalorieGoal == null ? null : goals.dailyCalorieGoal - calories,
    protein: goals.dailyProteinGoal == null ? null : goals.dailyProteinGoal - protein,
  };
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

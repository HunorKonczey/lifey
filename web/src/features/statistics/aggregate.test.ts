import { describe, it, expect } from "vitest";
import { aggregate, type RawData } from "./aggregate";
import type { MealResponse } from "@/features/nutrition/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";

const emptyRaw: RawData = { meals: [], weights: [], water: [], steps: [], sessions: [] };

describe("aggregate", () => {
  it("returns zeroed KPIs for empty data", () => {
    const start = new Date("2026-06-01T00:00:00Z");
    const end = new Date("2026-06-07T00:00:00Z");
    const r = aggregate(emptyRaw, start, end);
    expect(r.avgCalories).toBe(0);
    expect(r.workoutCount).toBe(0);
    expect(r.totalVolume).toBe(0);
    expect(r.latestWeight).toBeNull();
    expect(r.caloriesSeries).toHaveLength(7);
  });

  it("sums meal calories per day and averages over logged days", () => {
    const meals: MealResponse[] = [
      { id: 1, dateTime: "2026-06-02T12:00:00Z", mealType: "LUNCH", name: null,
        entries: [{ foodId: 1, foodName: "x", quantityInGrams: 100, calories: 500, protein: 30, carbs: 40, fat: 10 }] },
      { id: 2, dateTime: "2026-06-02T18:00:00Z", mealType: "DINNER", name: null,
        entries: [{ foodId: 2, foodName: "y", quantityInGrams: 100, calories: 300, protein: 20, carbs: 25, fat: 8 }] },
    ];
    const r = aggregate({ ...emptyRaw, meals }, new Date("2026-06-01T00:00:00Z"), new Date("2026-06-07T00:00:00Z"));
    // Only one day has data → avg = 800
    expect(r.avgCalories).toBe(800);
  });

  it("computes training volume as sum of weight × reps", () => {
    const sessions: WorkoutSessionResponse[] = [
      {
        id: 1, startedAt: "2026-06-03T10:00:00Z", finishedAt: "2026-06-03T11:00:00Z",
        exercises: [{ exerciseId: 1, exerciseName: "Bench" }],
        sets: [
          { exerciseId: 1, exerciseName: "Bench", reps: 10, weight: 60, performedAt: "2026-06-03T10:05:00Z" },
          { exerciseId: 1, exerciseName: "Bench", reps: 8, weight: 70, performedAt: "2026-06-03T10:10:00Z" },
        ],
        activeCalories: null, averageHeartRate: null, healthWorkoutId: null,
        templateId: null, templateName: null,
      },
    ];
    const r = aggregate({ ...emptyRaw, sessions }, new Date("2026-06-01T00:00:00Z"), new Date("2026-06-07T00:00:00Z"));
    expect(r.totalVolume).toBe(60 * 10 + 70 * 8); // 1160
    expect(r.workoutCount).toBe(1);
  });

  it("excludes data outside the window", () => {
    const meals: MealResponse[] = [
      { id: 1, dateTime: "2026-05-01T12:00:00Z", mealType: "LUNCH", name: null,
        entries: [{ foodId: 1, foodName: "x", quantityInGrams: 100, calories: 999, protein: 10, carbs: 100, fat: 5 }] },
    ];
    const r = aggregate({ ...emptyRaw, meals }, new Date("2026-06-01T00:00:00Z"), new Date("2026-06-07T00:00:00Z"));
    expect(r.avgCalories).toBe(0);
  });
});

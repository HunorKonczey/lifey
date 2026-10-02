import { describe, expect, it } from "vitest";
import { buildFeed, buildHeatmap, dailyAverages, dayKey, recordEvents } from "./clientActivity";
import type { MealResponse } from "@/features/nutrition/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";

const meal = (dateTime: string): MealResponse => ({ id: 1, dateTime, mealType: "LUNCH", name: null, entries: [] }) as MealResponse;
const session = (id: number, startedAt: string, sets: { exerciseId: number; weight: number; reps: number; at: string }[] = [], templateName: string | null = "Láb"): WorkoutSessionResponse =>
  ({
    id,
    startedAt,
    finishedAt: null,
    exercises: [],
    sets: sets.map((s) => ({ exerciseId: s.exerciseId, exerciseName: "Guggolás", weight: s.weight, reps: s.reps, performedAt: s.at })),
    templateName,
    sessionKind: "STRENGTH",
  }) as unknown as WorkoutSessionResponse;

// Thursday 1 Oct 2026, local noon.
const TODAY = new Date(2026, 9, 1, 12, 0, 0);

describe("buildHeatmap", () => {
  it("is four Monday-first weeks ending with the current one", () => {
    const grid = buildHeatmap({ meals: [], sessions: [], weights: [] }, TODAY);
    expect(grid).toHaveLength(4);
    expect(grid.map((w) => w.weekStart)).toEqual(["2026-09-07", "2026-09-14", "2026-09-21", "2026-09-28"]);
    expect(grid[0].cells[0].date).toBe("2026-09-07");
    expect(grid[3].cells.map((c) => c.date)).toEqual(["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04"]);
  });
  it("marks today and the days after it, and never dots a future day", () => {
    const grid = buildHeatmap({ meals: [meal(new Date(2026, 9, 3, 9).toISOString())], sessions: [], weights: [] }, TODAY);
    const last = grid[3].cells;
    expect(last[3].isToday).toBe(true);
    expect(last[4].isFuture).toBe(true);
    expect(last[5]).toMatchObject({ isFuture: true, kinds: [] });
  });
  it("puts meal, workout and weigh-in on one day in that order", () => {
    const grid = buildHeatmap(
      {
        meals: [meal(new Date(2026, 8, 29, 8).toISOString())],
        sessions: [session(1, new Date(2026, 8, 29, 18).toISOString())],
        weights: [{ id: 1, date: "2026-09-29", weight: 70 }],
      },
      TODAY,
    );
    expect(grid[3].cells[1].kinds).toEqual(["meal", "workout", "weight"]);
  });
  it("crosses a month boundary without losing a day", () => {
    const grid = buildHeatmap({ meals: [meal(new Date(2026, 8, 30, 8).toISOString())], sessions: [], weights: [] }, TODAY);
    expect(grid[3].cells[2]).toMatchObject({ date: "2026-09-30", kinds: ["meal"] });
    expect(grid[3].cells[3].date).toBe("2026-10-01");
  });
});

describe("recordEvents", () => {
  const sets = (list: [number, number, string][]) => list.map(([weight, reps, at]) => ({ exerciseId: 1, weight, reps, at }));
  it("does not announce the first set of an exercise", () => {
    const s = session(1, "2026-09-20T10:00:00Z", sets([[60, 8, "2026-09-20T10:05:00Z"]]));
    expect(recordEvents([s])).toEqual([]);
  });
  it("announces a heavier set than anything before it", () => {
    const a = session(1, "2026-09-20T10:00:00Z", sets([[60, 8, "2026-09-20T10:05:00Z"]]));
    const b = session(2, "2026-09-27T10:00:00Z", sets([[70, 6, "2026-09-27T10:05:00Z"], [65, 8, "2026-09-27T10:10:00Z"]]));
    const events = recordEvents([b, a]);
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ exerciseName: "Guggolás", weight: 70, reps: 6 });
  });
});

describe("buildFeed", () => {
  it("lists the newest events first, collapsing meals logged within the hour", () => {
    const feed = buildFeed(
      {
        meals: [meal("2026-09-30T12:00:00Z"), meal("2026-09-30T12:20:00Z"), meal("2026-09-29T08:00:00Z")],
        sessions: [session(1, "2026-09-30T17:00:00Z")],
        weights: [{ id: 1, date: "2026-09-28", weight: 69.6 }],
      },
      10,
    );
    expect(feed.map((e) => e.kind)).toEqual(["workout", "meal", "meal", "weight"]);
  });
  it("respects the limit", () => {
    const meals = ["2026-09-30T08:00:00Z", "2026-09-29T08:00:00Z", "2026-09-28T08:00:00Z"].map(meal);
    expect(buildFeed({ meals, sessions: [], weights: [] }, 2)).toHaveLength(2);
  });
});

describe("dayKey", () => {
  it("uses the local day", () => {
    expect(dayKey(new Date(2026, 0, 5, 23, 59))).toBe("2026-01-05");
  });
});

describe("dailyAverages", () => {
  const entry = (calories: number, protein: number) => ({ foodId: 1, foodName: "x", quantityInGrams: 100, calories, protein, carbs: 0, fat: 0 });
  const mealWith = (date: Date, ...entries: ReturnType<typeof entry>[]): MealResponse => ({ id: 1, dateTime: date.toISOString(), mealType: "LUNCH", name: null, entries }) as MealResponse;
  it("averages over logged days only", () => {
    const meals = [
      mealWith(new Date(2026, 9, 1, 9), entry(500, 30), entry(300, 20)),
      mealWith(new Date(2026, 8, 29, 9), entry(1000, 50)),
    ];
    expect(dailyAverages(meals, TODAY)).toEqual({ loggedDays: 2, kcal: 900, protein: 50 });
  });
  it("ignores meals outside the window and is null when nothing is left", () => {
    expect(dailyAverages([mealWith(new Date(2026, 8, 20, 9), entry(500, 30))], TODAY)).toBeNull();
    expect(dailyAverages([], TODAY)).toBeNull();
  });
});

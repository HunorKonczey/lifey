import { describe, expect, it } from "vitest";
import { weekDays, weekStats } from "./weekCalories";

// Wednesday 30 Sep 2026, mid-morning.
const now = new Date(2026, 8, 30, 9, 30);

function meal(day: number, hour: number, kcal: number[]) {
  return {
    dateTime: new Date(2026, 8, day, hour, 0).toISOString(),
    entries: kcal.map((calories) => ({ foodId: 1, foodName: "x", quantityInGrams: 100, calories, protein: 0, carbs: 0, fat: 0 })),
  };
}

/** 24..29 Sep logged like the canvas' "5 of 6 within goal", today partly. */
const meals = [
  meal(24, 8, [700, 900]), // 1 600
  meal(25, 13, [2100]), // 2 100 — over
  meal(26, 19, [1800]), // 1 800
  // 27 — nothing logged
  meal(28, 8, [500]),
  meal(28, 19, [1200]), // 1 700 over two meals
  meal(29, 12, [1900]), // exactly the goal
  meal(30, 8, [400]), // today, partial
];

describe("weekDays", () => {
  const days = weekDays(meals, now, now);

  it("is seven consecutive days ending on the shown day, oldest first", () => {
    expect(days).toHaveLength(7);
    expect(days[0].date.getDate()).toBe(24);
    expect(days[6].date.getDate()).toBe(30);
  });

  it("sums a day's meals and gives an unlogged day 0", () => {
    expect(days.map((d) => d.kcal)).toEqual([1600, 2100, 1800, 0, 1700, 1900, 400]);
  });

  it("marks only the real today as partial", () => {
    expect(days.map((d) => d.isToday)).toEqual([false, false, false, false, false, false, true]);
  });

  it("looking at a past day: every day is complete", () => {
    const past = weekDays(meals, new Date(2026, 8, 28), now);
    expect(past[6].date.getDate()).toBe(28);
    expect(past.every((d) => !d.isToday)).toBe(true);
  });

  it("crosses a month boundary", () => {
    const d = weekDays([], new Date(2026, 9, 2), new Date(2026, 9, 2));
    expect(d.map((x) => x.date.getDate())).toEqual([26, 27, 28, 29, 30, 1, 2]);
  });
});

describe("weekStats", () => {
  const days = weekDays(meals, now, now);
  const sessions = [
    new Date(2026, 8, 23, 18, 0).toISOString(), // before the window
    new Date(2026, 8, 24, 7, 0).toISOString(), // first day, start of window
    new Date(2026, 8, 26, 17, 30).toISOString(),
    new Date(2026, 8, 30, 6, 0).toISOString(), // today counts as a workout
    new Date(2026, 9, 1, 6, 0).toISOString(), // after the window
  ];

  it("averages the complete days that have something logged — not today, not the empty day", () => {
    // (1600 + 2100 + 1800 + 1700 + 1900) / 5
    expect(weekStats(days, 1900, sessions, now).averageKcal).toBeCloseTo(1820, 6);
  });

  it("counts days within goal out of the complete days; exactly the goal counts, an unlogged day doesn't", () => {
    const s = weekStats(days, 1900, sessions, now);
    // within: 1600, 1800, 1700, 1900  (2100 over, 0 not logged)
    expect(s.withinGoal).toBe(4);
    expect(s.completeDays).toBe(6);
  });

  it("has no within-goal figure without a calorie goal", () => {
    expect(weekStats(days, null, sessions, now).withinGoal).toBeNull();
    expect(weekStats(days, 0, sessions, now).withinGoal).toBeNull();
  });

  it("counts the sessions started inside the seven days", () => {
    expect(weekStats(days, 1900, sessions, now).workouts).toBe(3);
  });

  it("with nothing logged: no average, none within goal", () => {
    const empty = weekDays([], now, now);
    const s = weekStats(empty, 1900, [], now);
    expect(s.averageKcal).toBeNull();
    expect(s.withinGoal).toBe(0);
    expect(s.workouts).toBe(0);
  });

  it("viewing a past day: all seven count as complete", () => {
    const past = weekDays(meals, new Date(2026, 8, 29), now);
    expect(weekStats(past, 1900, [], now).completeDays).toBe(7);
  });
});

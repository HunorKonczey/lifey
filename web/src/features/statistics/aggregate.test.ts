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
        templateId: null, templateName: null, rpe: null, feedbackNote: null,
        trainerComment: null, trainerCommentAt: null,
        sessionKind: "STRENGTH", activityType: null, movingSeconds: null,
        cardio: null, splits: [], waypoints: [],
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

// ─── Cardio parity with mobile (docs/cardio/56-cardio-statistics-plan.md
// §2–§3, D-C3.7: "the definitions live in this doc, both codebases'
// comments point back to it"). Vitest can't literally execute the mobile
// Dart suite in the same run, so "parity" here means: implement the exact
// documented formula, and — where mobile already has its own test for the
// same rule (`stat_chart_data_test.dart`) — reuse its fixture numbers, so a
// human comparing the two suites side by side sees matching inputs and
// matching outputs. ───

let nextId = 1;

function strengthSession(overrides: Partial<WorkoutSessionResponse> = {}): WorkoutSessionResponse {
  const id = nextId++;
  return {
    id,
    startedAt: `2026-06-0${2 + (id % 5)}T10:00:00Z`,
    finishedAt: `2026-06-0${2 + (id % 5)}T11:00:00Z`,
    exercises: [], sets: [],
    activeCalories: null, averageHeartRate: null, healthWorkoutId: null,
    templateId: null, templateName: null, rpe: null, feedbackNote: null,
    trainerComment: null, trainerCommentAt: null,
    sessionKind: "STRENGTH", activityType: null, movingSeconds: null,
    cardio: null, splits: [], waypoints: [],
    ...overrides,
  };
}

function cardioSession(overrides: Partial<WorkoutSessionResponse> = {}): WorkoutSessionResponse {
  return {
    ...strengthSession(),
    sessionKind: "CARDIO",
    activityType: "RUNNING",
    ...overrides,
  };
}

describe("aggregate — cardio parity with mobile (docs/cardio/56)", () => {
  const start = new Date("2026-06-01T00:00:00Z");
  const end = new Date("2026-06-07T00:00:00Z");

  it("D-C3.1: workoutCount stays the total, strength and cardio alike", () => {
    const sessions = [strengthSession({ startedAt: "2026-06-03T09:00:00Z" }), cardioSession({ startedAt: "2026-06-03T18:00:00Z" })];
    const r = aggregate({ ...emptyRaw, sessions }, start, end);
    expect(r.workoutCount).toBe(2);
  });

  it("D-C3.2: strengthWorkoutCount/cardioWorkoutCount is an additive breakdown of workoutCount", () => {
    const sessions = [
      strengthSession({ startedAt: "2026-06-02T09:00:00Z" }),
      strengthSession({ startedAt: "2026-06-03T09:00:00Z" }),
      cardioSession({ startedAt: "2026-06-04T09:00:00Z" }),
    ];
    const r = aggregate({ ...emptyRaw, sessions }, start, end);
    expect(r.strengthWorkoutCount).toBe(2);
    expect(r.cardioWorkoutCount).toBe(1);
    expect(r.strengthWorkoutCount + r.cardioWorkoutCount).toBe(r.workoutCount);
  });

  it("cardioDistance sums km for DISTANCE and MACHINE, skips GAME — same fixture as the mobile stat_chart_data_test.dart", () => {
    const sessions = [
      cardioSession({
        startedAt: "2026-06-02T07:00:00Z", activityType: "RUNNING",
        cardio: { distanceMeters: 5000 } as WorkoutSessionResponse["cardio"],
      }),
      cardioSession({
        startedAt: "2026-06-02T12:00:00Z", activityType: "INDOOR_BIKE",
        cardio: { distanceMeters: 15000 } as WorkoutSessionResponse["cardio"],
      }),
      cardioSession({
        startedAt: "2026-06-02T18:00:00Z", activityType: "BASKETBALL",
        cardio: { distanceMeters: 2000 } as WorkoutSessionResponse["cardio"],
      }),
    ];
    const r = aggregate({ ...emptyRaw, sessions }, start, end);
    expect(r.cardioDistanceSeries).toHaveLength(1);
    expect(r.cardioDistanceSeries[0].value).toBe(20); // (5000+15000)/1000, basketball excluded
    expect(r.totalCardioDistanceKm).toBe(20);
  });

  it("D-C3.5: a day with no cardio distance is omitted from the series, not a 0.00 point", () => {
    const sessions = [
      cardioSession({ startedAt: "2026-06-02T07:00:00Z", cardio: { distanceMeters: 5000 } as WorkoutSessionResponse["cardio"] }),
      // A running session with no distance recorded yet (M11: no distance source).
      cardioSession({ startedAt: "2026-06-04T07:00:00Z", cardio: null }),
    ];
    const r = aggregate({ ...emptyRaw, sessions }, start, end);
    expect(r.cardioDistanceSeries).toHaveLength(1);
    expect(r.cardioDistanceSeries.some((p) => p.value === 0)).toBe(false);
  });

  it("D-C3.4: STRENGTH filter excludes cardio from workoutCount/totalVolume, and cardioDistanceSeries goes empty", () => {
    const sessions = [
      strengthSession({
        startedAt: "2026-06-03T09:00:00Z",
        sets: [{ exerciseId: 1, exerciseName: "Bench", reps: 10, weight: 60, performedAt: "2026-06-03T09:05:00Z" }],
      }),
      cardioSession({ startedAt: "2026-06-04T09:00:00Z", cardio: { distanceMeters: 5000 } as WorkoutSessionResponse["cardio"] }),
    ];
    const r = aggregate({ ...emptyRaw, sessions }, start, end, "MMM d", "STRENGTH");
    expect(r.workoutCount).toBe(1);
    expect(r.totalVolume).toBe(600);
    expect(r.cardioDistanceSeries).toEqual([]);
    // The breakdown itself is unaffected by which filter is active.
    expect(r.strengthWorkoutCount).toBe(1);
    expect(r.cardioWorkoutCount).toBe(1);
  });

  it("D-C3.4: CARDIO filter excludes strength from workoutCount/totalVolume, cardioDistanceSeries unaffected", () => {
    const sessions = [
      strengthSession({
        startedAt: "2026-06-03T09:00:00Z",
        sets: [{ exerciseId: 1, exerciseName: "Bench", reps: 10, weight: 60, performedAt: "2026-06-03T09:05:00Z" }],
      }),
      cardioSession({ startedAt: "2026-06-04T09:00:00Z", cardio: { distanceMeters: 5000 } as WorkoutSessionResponse["cardio"] }),
    ];
    const r = aggregate({ ...emptyRaw, sessions }, start, end, "MMM d", "CARDIO");
    expect(r.workoutCount).toBe(1);
    expect(r.totalVolume).toBe(0);
    expect(r.totalCardioDistanceKm).toBe(5);
  });

  it("ALL (default) reproduces the pre-cardio behavior bit-for-bit on a pure-strength dataset", () => {
    const sessions = [
      strengthSession({
        startedAt: "2026-06-03T09:00:00Z",
        sets: [{ exerciseId: 1, exerciseName: "Bench", reps: 10, weight: 60, performedAt: "2026-06-03T09:05:00Z" }],
      }),
    ];
    const withDefault = aggregate({ ...emptyRaw, sessions }, start, end);
    const withExplicitAll = aggregate({ ...emptyRaw, sessions }, start, end, "MMM d", "ALL");
    expect(withDefault).toEqual(withExplicitAll);
    expect(withDefault.workoutCount).toBe(1);
    expect(withDefault.strengthWorkoutCount).toBe(1);
    expect(withDefault.cardioWorkoutCount).toBe(0);
    expect(withDefault.cardioDistanceSeries).toEqual([]);
  });
});

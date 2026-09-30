import { describe, expect, it } from "vitest";
import { summarizeSession } from "./sessionSummary";
import type { ExerciseSetResponse, WorkoutSessionResponse } from "./types";

let clock = 0;
function set(exerciseId: number, weight: number, reps: number, name = "Bench Press"): ExerciseSetResponse {
  return { exerciseId, exerciseName: name, weight, reps, performedAt: new Date(2026, 8, 1, 10, clock++).toISOString() };
}

function session(id: number, day: number, sets: ExerciseSetResponse[], over: Partial<WorkoutSessionResponse> = {}): WorkoutSessionResponse {
  const start = new Date(2026, 8, day, 17, 40);
  return {
    id,
    startedAt: start.toISOString(),
    finishedAt: new Date(start.getTime() + 52 * 60_000).toISOString(),
    exercises: [...new Set(sets.map((s) => s.exerciseId))].map((exerciseId) => ({
      exerciseId,
      exerciseName: sets.find((s) => s.exerciseId === exerciseId)!.exerciseName,
    })) as WorkoutSessionResponse["exercises"],
    sets,
    activeCalories: null,
    averageHeartRate: null,
    healthWorkoutId: null,
    templateId: null,
    templateName: null,
    rpe: null,
    feedbackNote: null,
    trainerComment: null,
    trainerCommentAt: null,
    sessionKind: "STRENGTH",
    activityType: null,
    movingSeconds: null,
    cardio: null,
    splits: [],
    waypoints: [],
    ...over,
  };
}

describe("summarizeSession", () => {
  const last = session(1, 19, [set(1, 45, 8), set(1, 47.5, 8)]);
  const today = session(2, 26, [set(1, 45, 8), set(1, 47.5, 8), set(1, 50, 8), set(1, 50, 8)]);

  it("time and volume", () => {
    const s = summarizeSession(today, [last, today]);
    expect(s.seconds).toBe(52 * 60);
    expect(s.volumeKg).toBe(45 * 8 + 47.5 * 8 + 50 * 8 * 2);
  });

  it("best set per exercise, with ↑ when it beat last time", () => {
    const s = summarizeSession(today, [last, today]);
    expect(s.exercises).toHaveLength(1);
    expect(s.exercises[0].best).toEqual({ weight: 50, reps: 8 });
    expect(s.exercises[0].sets).toHaveLength(4);
    expect(s.exercises[0].improved).toBe(true);
  });

  it("no ↑ when it only matched last time, or there is no last time", () => {
    const same = session(3, 27, [set(1, 47.5, 8)]);
    expect(summarizeSession(same, [last, same]).exercises[0].improved).toBe(false);
    expect(summarizeSession(last, [last]).exercises[0].improved).toBe(false);
  });

  it("the record names the set and what stood before", () => {
    const s = summarizeSession(today, [last, today]);
    expect(s.records).toHaveLength(1);
    expect(s.records[0].exerciseName).toBe("Bench Press");
    expect(s.records[0].set).toEqual({ weight: 50, reps: 8 });
    expect(s.records[0].previous).toEqual({ weight: 47.5, reps: 8 });
    expect(s.records[0].kinds).toContain("maxWeight");
  });

  it("a first-ever session with one set has no records (nothing to beat); climbing within it counts, same as the list chip", () => {
    const one = session(7, 19, [set(1, 45, 8)]);
    expect(summarizeSession(one, [one]).records).toEqual([]);
    const climb = summarizeSession(last, [last]).records;
    expect(climb).toHaveLength(1);
    expect(climb[0].previous).toBeNull();
  });

  it("only history before the session counts — a later session does not hide its record", () => {
    const later = session(9, 30, [set(1, 100, 5)]);
    expect(summarizeSession(today, [last, today, later]).records).toHaveLength(1);
  });

  it("an unfinished earlier session is not history", () => {
    const open = session(4, 20, [set(1, 80, 5)], { finishedAt: null });
    expect(summarizeSession(today, [open, last, today]).records[0].previous).toEqual({ weight: 47.5, reps: 8 });
  });

  it("records are listed heaviest first", () => {
    const squatHist = session(5, 19, [set(2, 60, 8, "Squat"), set(1, 45, 8)]);
    const both = session(6, 26, [set(1, 50, 8), set(2, 62.5, 8, "Squat")]);
    const s = summarizeSession(both, [squatHist, both]);
    expect(s.records.map((r) => r.exerciseName)).toEqual(["Squat", "Bench Press"]);
  });
});

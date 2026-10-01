import { describe, expect, it } from "vitest";
import { summarizeTemplate } from "./recommendedSummary";
import type { WorkoutSessionResponse, WorkoutTemplateResponse } from "./types";

const template: WorkoutTemplateResponse = {
  id: 7,
  name: "Leg day",
  exercises: [
    { exerciseId: 1, targetSets: 4 },
    { exerciseId: 2, targetSets: 3 },
    { exerciseId: 3, targetSets: 3 },
    { exerciseId: 4, targetSets: 4 },
    { exerciseId: 5, targetSets: 2 },
    { exerciseId: 6, targetSets: 2 },
  ],
};
const names = new Map([
  [1, "Squat"],
  [2, "Lunge"],
  [3, "Leg curl"],
]);

function session(over: Partial<WorkoutSessionResponse> & { startedAt: string }): WorkoutSessionResponse {
  return {
    id: 1,
    finishedAt: null,
    exercises: [],
    sets: [],
    activeCalories: null,
    averageHeartRate: null,
    healthWorkoutId: null,
    templateId: 7,
    templateName: "Leg day",
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

/** A finished session of `minutes` length on `day` of September 2026. */
function done(day: number, minutes: number, extra: Partial<WorkoutSessionResponse> = {}) {
  const start = new Date(2026, 8, day, 18, 0);
  return session({ startedAt: start.toISOString(), finishedAt: new Date(start.getTime() + minutes * 60_000).toISOString(), ...extra });
}

describe("summarizeTemplate", () => {
  it("counts exercises and sums the target sets", () => {
    const s = summarizeTemplate(template, [], names);
    expect(s.exerciseCount).toBe(6);
    expect(s.totalSets).toBe(18);
  });

  it("without history: 8 minutes an exercise, rounded to 5 (6 × 8 = 48 → 50)", () => {
    expect(summarizeTemplate(template, [], names).estimatedMinutes).toBe(50);
    expect(summarizeTemplate({ ...template, exercises: template.exercises.slice(0, 2) }, [], names).estimatedMinutes).toBe(15);
  });

  it("with history: the median of the template's finished durations, rounded to 5", () => {
    const sessions = [done(27, 52), done(25, 61), done(23, 44)]; // median 52 → 50
    expect(summarizeTemplate(template, sessions, names).estimatedMinutes).toBe(50);
    expect(summarizeTemplate(template, [done(27, 58), done(25, 62)], names).estimatedMinutes).toBe(60); // median 60
  });

  it("ignores unfinished sessions, zero-length ones and other templates for the estimate", () => {
    const sessions = [
      session({ startedAt: new Date(2026, 8, 28, 9, 0).toISOString() }), // unfinished
      done(27, 0), // closed instantly
      done(26, 90, { templateId: 99 }), // a different template
      done(25, 40),
    ];
    expect(summarizeTemplate(template, sessions, names).estimatedMinutes).toBe(40);
  });

  it("never estimates below 5 minutes", () => {
    expect(summarizeTemplate(template, [done(25, 1)], names).estimatedMinutes).toBe(5);
  });

  it("lastPerformed is the newest finished session of this template", () => {
    const s = summarizeTemplate(template, [done(27, 50), done(23, 50)], names);
    expect(s.lastPerformed?.getDate()).toBe(27);
    expect(summarizeTemplate(template, [], names).lastPerformed).toBeNull();
  });

  it("previews the first three exercises with their names and target sets", () => {
    const s = summarizeTemplate(template, [], names);
    expect(s.preview.map((p) => [p.name, p.sets])).toEqual([
      ["Squat", 4],
      ["Lunge", 3],
      ["Leg curl", 3],
    ]);
    expect(s.preview.every((p) => p.reps === null)).toBe(true);
  });

  it("takes each exercise's typical reps from the newest session that logged it", () => {
    const set = (exerciseId: number, reps: number) => ({ exerciseId, exerciseName: "", reps, weight: 80, performedAt: "2026-09-27T18:10:00Z" });
    const newest = done(27, 50, { sets: [set(1, 8), set(1, 8), set(1, 10)] });
    const older = done(25, 50, { sets: [set(1, 5), set(2, 12)] });
    const s = summarizeTemplate(template, [newest, older], names);
    expect(s.preview[0].reps).toBe(8); // newest session's median
    expect(s.preview[1].reps).toBe(12); // newest session that has Lunge is the older one
    expect(s.preview[2].reps).toBeNull(); // never logged
  });
});

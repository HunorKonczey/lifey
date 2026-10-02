import { describe, expect, it } from "vitest";
import { celebrationData } from "./finishSummary";
import type { WorkoutSessionResponse } from "./types";

const mk = (id: number, start: Date, over: Partial<WorkoutSessionResponse> = {}): WorkoutSessionResponse =>
  ({
    id,
    startedAt: start.toISOString(),
    finishedAt: new Date(start.getTime() + 50 * 60_000).toISOString(),
    exercises: [{ exerciseId: 1, exerciseName: "Squat" }],
    sets: [],
    sessionKind: "STRENGTH",
    templateId: null,
    ...over,
  }) as unknown as WorkoutSessionResponse;

const past = mk(1, new Date(2026, 8, 20, 18), {
  sets: [{ exerciseId: 1, exerciseName: "Squat", weight: 60, reps: 8, performedAt: new Date(2026, 8, 20, 18, 10).toISOString() }],
});
const running = mk(2, new Date(2026, 8, 24, 17, 0), { finishedAt: null });
const done = new Date(2026, 8, 24, 17, 51);

describe("celebrationData", () => {
  const drafts = [
    { exerciseId: 1, weight: 60, reps: 8, done: true },
    { exerciseId: 1, weight: 62.5, reps: 8, done: true },
    { exerciseId: 1, weight: 65, reps: 5, done: false },
    { exerciseId: 1, weight: 65, reps: 0, done: true },
  ];

  it("time, volume and set count come from the ticked sets only", () => {
    const c = celebrationData(running, drafts, [past, running], done);
    expect(c.seconds).toBe(51 * 60);
    expect(c.sets).toBe(2);
    expect(c.volumeKg).toBe(60 * 8 + 62.5 * 8);
  });

  it("records list the record set with what stood before, like the summary panel", () => {
    const c = celebrationData(running, drafts, [past, running], done);
    expect(c.records).toHaveLength(1);
    expect(c.records[0].set).toEqual({ weight: 62.5, reps: 8 });
    expect(c.records[0].previous).toEqual({ weight: 60, reps: 8 });
  });

  it("no record when nothing beat the history", () => {
    const c = celebrationData(running, [{ exerciseId: 1, weight: 55, reps: 8, done: true }], [past, running], done);
    expect(c.records).toEqual([]);
  });

  it("counts this week's workouts including this one, once", () => {
    const monday = mk(3, new Date(2026, 8, 21, 7));
    const lastWeek = mk(4, new Date(2026, 8, 18, 7));
    expect(celebrationData(running, drafts, [past, lastWeek, monday, running], done).weekCount).toBe(2);
    expect(celebrationData(running, drafts, [past, lastWeek, monday], done).weekCount).toBe(2); // not in the list yet
    expect(celebrationData(running, drafts, [], done).weekCount).toBe(1);
  });
});

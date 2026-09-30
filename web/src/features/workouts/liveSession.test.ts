import { describe, expect, it } from "vitest";
import { elapsedSeconds, firstOpenExerciseId, hasUnsavedSets, liveProgress, railExercises, type DraftSet } from "./liveSession";

const ex = (id: number, name = `E${id}`) => ({ exerciseId: id, exerciseName: name });
const d = (exerciseId: number, done: boolean, weight = 50, reps = 8): DraftSet => ({ exerciseId, weight, reps, done });

describe("elapsedSeconds", () => {
  const start = new Date(2026, 8, 30, 10, 0, 0).toISOString();
  it("counts from startedAt to now while running", () => {
    expect(elapsedSeconds(start, null, new Date(2026, 8, 30, 10, 24, 18).getTime())).toBe(24 * 60 + 18);
  });

  it("a reload changes nothing — it is a function of the timestamps", () => {
    const now = new Date(2026, 8, 30, 10, 5, 0).getTime();
    expect(elapsedSeconds(start, null, now)).toBe(elapsedSeconds(start, null, now));
  });

  it("a finished session stops at its own length", () => {
    const end = new Date(2026, 8, 30, 10, 52, 0).toISOString();
    expect(elapsedSeconds(start, end, new Date(2026, 9, 5).getTime())).toBe(52 * 60);
  });

  it("never negative (clock skew)", () => {
    expect(elapsedSeconds(start, null, new Date(2026, 8, 30, 9, 59, 50).getTime())).toBe(0);
  });
});

describe("railExercises", () => {
  it("done, current and next", () => {
    const rail = railExercises([ex(1), ex(2), ex(3)], [d(1, true), d(1, true), d(2, false), d(2, true)], 2);
    expect(rail.map((r) => r.state)).toEqual(["done", "current", "next"]);
    expect(rail[1]).toMatchObject({ doneSets: 1, totalSets: 2 });
  });

  it("an exercise with no sets yet is next, never done", () => {
    expect(railExercises([ex(1)], [], null)[0].state).toBe("next");
  });

  it("the current exercise stays current even when all its sets are done", () => {
    expect(railExercises([ex(1)], [d(1, true)], 1)[0].state).toBe("current");
  });
});

describe("firstOpenExerciseId", () => {
  it("skips finished exercises", () => {
    expect(firstOpenExerciseId([ex(1), ex(2)], [d(1, true), d(2, false)])).toBe(2);
  });

  it("everything done (or nothing planned): the first exercise; no exercises: null", () => {
    expect(firstOpenExerciseId([ex(1), ex(2)], [d(1, true), d(2, true)])).toBe(1);
    expect(firstOpenExerciseId([], [])).toBeNull();
  });
});

describe("liveProgress", () => {
  it("9 of 18 sets, 1 of 2 exercises", () => {
    const drafts = [...Array(4).fill(0).map(() => d(1, true)), ...Array(5).fill(0).map(() => d(2, true)), d(2, false)];
    expect(liveProgress([ex(1), ex(2)], drafts, 18)).toEqual({ doneSets: 9, totalSets: 18, doneExercises: 1, totalExercises: 2 });
  });

  it("the total grows past the plan when more sets were added, and is the log without a template", () => {
    expect(liveProgress([ex(1)], [d(1, true), d(1, true), d(1, true)], 2).totalSets).toBe(3);
    expect(liveProgress([ex(1)], [d(1, true)], 0).totalSets).toBe(1);
  });
});

describe("hasUnsavedSets", () => {
  const saved = [
    { exerciseId: 1, exerciseName: "E1", weight: 50, reps: 8, performedAt: "" },
    { exerciseId: 1, exerciseName: "E1", weight: 52.5, reps: 8, performedAt: "" },
  ];

  it("the same sets in any order are saved", () => {
    expect(hasUnsavedSets(saved, [d(1, true, 52.5, 8), d(1, true, 50, 8)])).toBe(false);
  });

  it("an added, changed or removed set is unsaved", () => {
    expect(hasUnsavedSets(saved, [d(1, true, 50, 8), d(1, true, 52.5, 8), d(1, true, 55, 6)])).toBe(true);
    expect(hasUnsavedSets(saved, [d(1, true, 50, 8), d(1, true, 52.5, 9)])).toBe(true);
    expect(hasUnsavedSets(saved, [d(1, true, 50, 8)])).toBe(true);
  });

  it("an undone or empty-reps set is not sent, so it is not a difference", () => {
    expect(hasUnsavedSets(saved, [d(1, true, 50, 8), d(1, true, 52.5, 8), d(1, false, 60, 5), d(1, true, 60, 0)])).toBe(false);
  });
});

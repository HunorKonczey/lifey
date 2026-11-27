import { describe, expect, it } from "vitest";
import {
  normalizeExerciseNote,
  plannedExercisesRequest,
  previousExerciseNote,
} from "./exerciseNotes";
import type { ExerciseSummary, WorkoutSessionResponse } from "./types";

const ex = (
  exerciseId: number,
  note: string | null = null,
  targetSets: number | null = null,
): ExerciseSummary => ({
  exerciseId,
  exerciseName: `E${exerciseId}`,
  targetSets,
  note,
});

const session = (id: number, startedAt: string, exercises: ExerciseSummary[]) =>
  ({ id, startedAt, exercises }) as unknown as WorkoutSessionResponse;

describe("normalizeExerciseNote", () => {
  it("trims, and a blank comment is no comment", () => {
    expect(normalizeExerciseNote("  Seat on 4 \n")).toBe("Seat on 4");
    expect(normalizeExerciseNote("   ")).toBeNull();
    expect(normalizeExerciseNote(null)).toBeNull();
    expect(normalizeExerciseNote(undefined)).toBeNull();
  });
});

describe("previousExerciseNote", () => {
  const history = [
    session(1, "2026-11-01T10:00:00Z", [ex(7, "Seat on 3")]),
    session(2, "2026-11-08T10:00:00Z", [ex(7, "Seat on 4"), ex(8)]),
    session(3, "2026-11-15T10:00:00Z", [ex(9, "Other exercise")]),
    session(4, "2026-11-20T10:00:00Z", [ex(7, "This session")]),
  ];

  it("takes the latest other session that planned the exercise", () => {
    expect(previousExerciseNote(history, 4, 7)).toBe("Seat on 4");
  });

  it("is null when that session had no comment, even if an older one did — a cleared comment stays cleared", () => {
    const cleared = [...history, session(5, "2026-11-10T10:00:00Z", [ex(7, null)])];
    expect(previousExerciseNote(cleared, 4, 7)).toBeNull();
  });

  it("is null for an exercise no other session planned", () => {
    expect(previousExerciseNote(history, 4, 42)).toBeNull();
    expect(previousExerciseNote(history, 2, 8)).toBeNull();
  });

  it("breaks a startedAt tie by the higher id, like the server", () => {
    const tie = [
      session(10, "2026-11-01T10:00:00Z", [ex(7, "older id")]),
      session(11, "2026-11-01T10:00:00Z", [ex(7, "newer id")]),
    ];
    expect(previousExerciseNote(tie, 99, 7)).toBe("newer id");
  });
});

describe("plannedExercisesRequest", () => {
  it("keeps every exercise's targetSets and its comment when nothing was edited", () => {
    expect(plannedExercisesRequest([ex(1, "Seat on 4", 3), ex(2, null, null)], new Map())).toEqual([
      { exerciseId: 1, targetSets: 3, note: "Seat on 4" },
      { exerciseId: 2, targetSets: null, note: null },
    ]);
  });

  it("an edited comment replaces the session's, and an emptied one clears it", () => {
    const edits = new Map<number, string | null>([
      [1, "  Seat on 5 "],
      [2, null],
    ]);
    expect(
      plannedExercisesRequest(
        [ex(1, "Seat on 4", 3), ex(2, "Grip wide", 4), ex(3, "Untouched")],
        edits,
      ),
    ).toEqual([
      { exerciseId: 1, targetSets: 3, note: "Seat on 5" },
      { exerciseId: 2, targetSets: 4, note: null },
      { exerciseId: 3, targetSets: null, note: "Untouched" },
    ]);
  });
});

import { describe, expect, it } from "vitest";
import { exerciseRequest, isExerciseDirty } from "./components/ExerciseEditorPanel";
import type { ExerciseResponse } from "./types";

const ex: ExerciseResponse = { id: 1, name: "Bench Press", category: "CHEST", equipment: "BARBELL", description: null, defaultRestSeconds: 120 };
const fields = (over: Partial<Parameters<typeof exerciseRequest>[0]> = {}) => ({ name: "Bench Press", category: "CHEST", equipment: "BARBELL", description: "", rest: 120 as number | null, ...over });

describe("exerciseRequest", () => {
  it("sends the rest time back — a PUT without it would clear it", () => {
    expect(exerciseRequest(fields())).toEqual({ name: "Bench Press", category: "CHEST", equipment: "BARBELL", description: null, defaultRestSeconds: 120 });
  });

  it("empty choices are null, the name and description are trimmed", () => {
    expect(exerciseRequest(fields({ name: "  Plank ", category: "", equipment: "", description: "  hold  ", rest: null }))).toEqual({
      name: "Plank",
      category: null,
      equipment: null,
      description: "hold",
      defaultRestSeconds: null,
    });
  });
});

describe("isExerciseDirty", () => {
  it("untouched fields are clean, any change is dirty", () => {
    expect(isExerciseDirty(ex, fields())).toBe(false);
    expect(isExerciseDirty(ex, fields({ name: "Bench" }))).toBe(true);
    expect(isExerciseDirty(ex, fields({ category: "BACK" }))).toBe(true);
    expect(isExerciseDirty(ex, fields({ rest: 90 }))).toBe(true);
    expect(isExerciseDirty(ex, fields({ rest: null }))).toBe(true);
  });

  it("whitespace around the name or description is not a change", () => {
    expect(isExerciseDirty(ex, fields({ name: "Bench Press " }))).toBe(false);
  });

  it("a new exercise is clean until something is typed", () => {
    expect(isExerciseDirty(null, { name: "", category: "", equipment: "", description: "", rest: null })).toBe(false);
    expect(isExerciseDirty(null, { name: "Row", category: "", equipment: "", description: "", rest: null })).toBe(true);
  });
});

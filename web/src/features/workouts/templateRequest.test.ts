import { describe, expect, it } from "vitest";
import { buildTemplateRequest, sanitizeCount } from "./templateRequest";

describe("sanitizeCount", () => {
  it("keeps the digits, so a number is a number", () => {
    expect(sanitizeCount("45", 1000)).toBe(45);
    expect(sanitizeCount(" 4x5 ", 1000)).toBe(45);
  });

  it("is null - not said - for nothing, text or zero", () => {
    for (const empty of ["", "  ", "abc", "0", "000", "-"]) expect(sanitizeCount(empty, 1000)).toBeNull();
  });

  it("holds a number above the cap at the cap", () => {
    expect(sanitizeCount("5000", 1000)).toBe(1000);
  });
});

describe("buildTemplateRequest (LIF-106)", () => {
  const saved = {
    durationMinutes: 45,
    exercises: [
      { exerciseId: 1, targetSets: 3, targetReps: 10 },
      { exerciseId: 2, targetSets: 3, targetReps: null },
    ],
  };

  it("sends what is set", () => {
    const req = buildTemplateRequest(saved, " Push ", [{ exerciseId: 1, targetSets: 4, targetReps: 12 }, { exerciseId: 2, targetSets: 3 }], 50);
    expect(req).toEqual({ name: "Push", exercises: [{ exerciseId: 1, targetSets: 4, targetReps: 12 }, { exerciseId: 2, targetSets: 3 }], durationMinutes: 50 });
  });

  it("says 0 for a duration or a count the author emptied, so the backend clears it instead of keeping it", () => {
    const req = buildTemplateRequest(saved, "Push", [{ exerciseId: 1, targetSets: 3, targetReps: null }, { exerciseId: 2, targetSets: 3 }], null);
    expect(req.durationMinutes).toBe(0);
    expect(req.exercises[0].targetReps).toBe(0);
    expect(req.exercises[1]).toEqual({ exerciseId: 2, targetSets: 3 });
  });

  it("leaves out a duration and counts that were never set", () => {
    const req = buildTemplateRequest(null, "New", [{ exerciseId: 1, targetSets: 3 }], null);
    expect(req).toEqual({ name: "New", exercises: [{ exerciseId: 1, targetSets: 3 }] });
    expect("durationMinutes" in req).toBe(false);
  });

  it("an exercise added during the edit carries no count unless one was typed", () => {
    const req = buildTemplateRequest(saved, "Push", [{ exerciseId: 9, targetSets: 3 }], 45);
    expect(req.exercises).toEqual([{ exerciseId: 9, targetSets: 3 }]);
  });
});

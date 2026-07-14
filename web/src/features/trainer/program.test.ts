import { describe, it, expect } from "vitest";
import { format } from "date-fns";
import {
  findSlot,
  setSlot,
  clearSlot,
  duplicateWeek,
  copyWeekToAll,
  slotsPerWeek,
  validateProgram,
  isProgramValid,
  dropOverflowWeeks,
  nextOrSameMonday,
  isValidProgramStartDate,
  programEndDate,
  currentWeekNumber,
  weeksBetween,
} from "./program";
import type { ProgramWorkoutRequest } from "./types";

function slot(overrides: Partial<ProgramWorkoutRequest> = {}): ProgramWorkoutRequest {
  return { weekNumber: 1, dayOfWeek: "MONDAY", templateId: 7, timeOfDay: null, note: null, ...overrides };
}

describe("findSlot", () => {
  it("finds a slot by week and day", () => {
    const workouts = [slot(), slot({ weekNumber: 1, dayOfWeek: "THURSDAY", templateId: 8 })];
    expect(findSlot(workouts, 1, "THURSDAY")?.templateId).toBe(8);
  });

  it("returns undefined when no slot matches", () => {
    expect(findSlot([slot()], 2, "MONDAY")).toBeUndefined();
  });
});

describe("setSlot", () => {
  it("adds a new slot", () => {
    const result = setSlot([], slot());
    expect(result).toHaveLength(1);
  });

  it("overwrites an existing slot at the same (week, day)", () => {
    const result = setSlot([slot({ templateId: 7 })], slot({ templateId: 99 }));
    expect(result).toHaveLength(1);
    expect(result[0].templateId).toBe(99);
  });

  it("leaves other slots untouched", () => {
    const other = slot({ weekNumber: 2, dayOfWeek: "FRIDAY", templateId: 1 });
    const result = setSlot([other], slot({ templateId: 99 }));
    expect(result).toContainEqual(other);
  });
});

describe("clearSlot", () => {
  it("removes the matching slot", () => {
    const result = clearSlot([slot()], 1, "MONDAY");
    expect(result).toHaveLength(0);
  });

  it("is a no-op when nothing matches", () => {
    const workouts = [slot()];
    expect(clearSlot(workouts, 2, "MONDAY")).toEqual(workouts);
  });
});

describe("duplicateWeek", () => {
  it("copies every slot from the source week onto the target week", () => {
    const workouts = [slot({ weekNumber: 1, dayOfWeek: "MONDAY" }), slot({ weekNumber: 1, dayOfWeek: "THURSDAY" })];
    const result = duplicateWeek(workouts, 1, 2);

    const week2 = result.filter((w) => w.weekNumber === 2);
    expect(week2).toHaveLength(2);
    expect(week2.map((w) => w.dayOfWeek).sort()).toEqual(["MONDAY", "THURSDAY"]);
  });

  it("overwrites whatever was already on the target week", () => {
    const workouts = [
      slot({ weekNumber: 1, dayOfWeek: "MONDAY", templateId: 1 }),
      slot({ weekNumber: 2, dayOfWeek: "FRIDAY", templateId: 99 }),
    ];
    const result = duplicateWeek(workouts, 1, 2);

    expect(result.filter((w) => w.weekNumber === 2)).toEqual([slot({ weekNumber: 2, dayOfWeek: "MONDAY", templateId: 1 })]);
  });

  it("is a no-op when the source week has no slots", () => {
    const workouts = [slot({ weekNumber: 2, dayOfWeek: "FRIDAY" })];
    expect(duplicateWeek(workouts, 1, 3)).toEqual(workouts);
  });
});

describe("copyWeekToAll", () => {
  it("copies the source week onto every other week", () => {
    const workouts = [slot({ weekNumber: 1, dayOfWeek: "MONDAY" })];
    const result = copyWeekToAll(workouts, 1, 3);

    expect(result.filter((w) => w.weekNumber === 1)).toHaveLength(1);
    expect(result.filter((w) => w.weekNumber === 2)).toHaveLength(1);
    expect(result.filter((w) => w.weekNumber === 3)).toHaveLength(1);
  });

  it("does not duplicate the source week onto itself", () => {
    const workouts = [slot({ weekNumber: 1, dayOfWeek: "MONDAY" })];
    const result = copyWeekToAll(workouts, 1, 2);

    expect(result.filter((w) => w.weekNumber === 1)).toHaveLength(1);
  });
});

describe("slotsPerWeek", () => {
  it("counts distinct days across the whole grid", () => {
    const workouts = [
      slot({ weekNumber: 1, dayOfWeek: "MONDAY" }),
      slot({ weekNumber: 1, dayOfWeek: "THURSDAY" }),
      slot({ weekNumber: 2, dayOfWeek: "MONDAY" }),
    ];
    expect(slotsPerWeek(workouts)).toBe(2);
  });

  it("is zero for an empty grid", () => {
    expect(slotsPerWeek([])).toBe(0);
  });
});

describe("validateProgram", () => {
  it("flags a blank name", () => {
    expect(validateProgram("  ", 4, [slot()]).nameError).toBe(true);
  });

  it("flags weeksCount outside 1-12", () => {
    expect(validateProgram("Block", 0, [slot()]).weeksCountError).toBe(true);
    expect(validateProgram("Block", 13, [slot()]).weeksCountError).toBe(true);
    expect(validateProgram("Block", 12, [slot()]).weeksCountError).toBe(false);
  });

  it("flags an empty grid", () => {
    expect(validateProgram("Block", 4, []).noSlotsError).toBe(true);
  });

  it("flags slots whose week exceeds weeksCount", () => {
    const workouts = [slot({ weekNumber: 5 })];
    expect(validateProgram("Block", 4, workouts).overflowWeeks).toEqual([5]);
  });

  it("a fully valid program has no errors", () => {
    const validation = validateProgram("Block", 4, [slot()]);
    expect(isProgramValid(validation)).toBe(true);
  });

  it("isProgramValid is false when any check fails", () => {
    expect(isProgramValid(validateProgram("", 4, [slot()]))).toBe(false);
    expect(isProgramValid(validateProgram("Block", 4, []))).toBe(false);
  });
});

describe("dropOverflowWeeks", () => {
  it("removes slots beyond the new weeksCount", () => {
    const workouts = [slot({ weekNumber: 1 }), slot({ weekNumber: 5 })];
    expect(dropOverflowWeeks(workouts, 2)).toEqual([slot({ weekNumber: 1 })]);
  });
});

describe("nextOrSameMonday", () => {
  it("returns the same date when it's already a Monday", () => {
    const monday = new Date("2026-07-13T15:00:00"); // a Monday
    expect(format(nextOrSameMonday(monday), "yyyy-MM-dd")).toBe("2026-07-13");
  });

  it("returns the following Monday for any other day", () => {
    const wednesday = new Date("2026-07-15T00:00:00");
    expect(format(nextOrSameMonday(wednesday), "yyyy-MM-dd")).toBe("2026-07-20");
  });

  it("strips the time of day", () => {
    const monday = new Date("2026-07-13T23:59:00");
    expect(nextOrSameMonday(monday).getHours()).toBe(0);
  });
});

describe("isValidProgramStartDate", () => {
  const today = new Date("2026-07-13T00:00:00"); // a Monday

  it("accepts today when today is a Monday", () => {
    expect(isValidProgramStartDate("2026-07-13", today)).toBe(true);
  });

  it("rejects a non-Monday", () => {
    expect(isValidProgramStartDate("2026-07-14", today)).toBe(false);
  });

  it("rejects a Monday in the past", () => {
    expect(isValidProgramStartDate("2026-07-06", today)).toBe(false);
  });

  it("accepts a future Monday", () => {
    expect(isValidProgramStartDate("2026-07-20", today)).toBe(true);
  });

  it("rejects an empty string", () => {
    expect(isValidProgramStartDate("", today)).toBe(false);
  });
});

describe("programEndDate", () => {
  it("computes start + weeks - 1 day", () => {
    expect(programEndDate("2026-07-13", 2)).toBe("2026-07-26");
  });

  it("a single week ends 6 days later", () => {
    expect(programEndDate("2026-07-13", 1)).toBe("2026-07-19");
  });
});

describe("currentWeekNumber", () => {
  const start = "2026-07-13"; // a Monday

  it("is week 1 on the start date", () => {
    expect(currentWeekNumber(start, 4, new Date("2026-07-13T12:00:00"))).toBe(1);
  });

  it("is week 1 anywhere within the first week", () => {
    expect(currentWeekNumber(start, 4, new Date("2026-07-19T12:00:00"))).toBe(1);
  });

  it("advances to week 2 on the second Monday", () => {
    expect(currentWeekNumber(start, 4, new Date("2026-07-20T12:00:00"))).toBe(2);
  });

  it("clamps to weeksCount after the run has ended", () => {
    expect(currentWeekNumber(start, 4, new Date("2026-12-01T12:00:00"))).toBe(4);
  });

  it("clamps to 1 before the run has started", () => {
    expect(currentWeekNumber(start, 4, new Date("2026-07-01T12:00:00"))).toBe(1);
  });
});

describe("weeksBetween", () => {
  it("is the exact inverse of programEndDate", () => {
    const start = "2026-07-13";
    for (const weeks of [1, 2, 4, 12]) {
      const end = programEndDate(start, weeks);
      expect(weeksBetween(start, end)).toBe(weeks);
    }
  });

  it("a single week (start === end - 6 days) is 1", () => {
    expect(weeksBetween("2026-07-13", "2026-07-19")).toBe(1);
  });

  it("four weeks matches the M5 assignment regression case", () => {
    expect(weeksBetween("2026-07-13", "2026-08-09")).toBe(4);
  });
});

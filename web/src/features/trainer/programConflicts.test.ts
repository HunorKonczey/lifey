import { describe, expect, it } from "vitest";
import { consequenceSummary, findConflicts, programOccurrences } from "./programConflicts";
import type { ProgramWorkoutRequest } from "./types";

const w = (weekNumber: number, dayOfWeek: ProgramWorkoutRequest["dayOfWeek"], timeOfDay: string | null = null): ProgramWorkoutRequest => ({ weekNumber, dayOfWeek, templateId: 1, timeOfDay, note: null });
const ex = (scheduledFor: string, scheduledTime: string | null, status: "UPCOMING" | "CANCELLED" | "DONE" | "MISSED" = "UPCOMING") => ({ scheduledFor, scheduledTime, status });

describe("programOccurrences", () => {
  it("lays weeks and days out from the Monday start, sorted", () => {
    const o = programOccurrences([w(2, "WEDNESDAY", "18:00"), w(1, "MONDAY", "07:30:00"), w(1, "FRIDAY")], "2026-09-28");
    expect(o.map((x) => [x.date, x.time])).toEqual([["2026-09-28", "07:30"], ["2026-10-02", null], ["2026-10-07", "18:00"]]);
  });
  it("crosses a month boundary", () => {
    const o = programOccurrences([w(1, "SUNDAY"), w(2, "MONDAY")], "2026-09-28");
    expect(o.map((x) => x.date)).toEqual(["2026-10-04", "2026-10-05"]);
  });
});

describe("consequenceSummary", () => {
  it("counts and spans the dates", () => {
    expect(consequenceSummary(programOccurrences([w(1, "MONDAY"), w(4, "FRIDAY")], "2026-09-28"))).toEqual({ count: 2, firstDate: "2026-09-28", lastDate: "2026-10-23" });
  });
  it("is null for a program with no workouts", () => {
    expect(consequenceSummary([])).toBeNull();
  });
});

describe("findConflicts", () => {
  const occ = programOccurrences([w(1, "MONDAY", "18:00"), w(1, "TUESDAY"), w(1, "WEDNESDAY", "07:00")], "2026-09-28");
  it("flags timed workouts within 60 minutes on the same day, not 60 or more", () => {
    expect(findConflicts(occ, [ex("2026-09-28", "18:30")])).toHaveLength(1);
    expect(findConflicts(occ, [ex("2026-09-28", "19:00")])).toHaveLength(0);
    expect(findConflicts(occ, [ex("2026-09-28", "17:01")])).toHaveLength(1);
  });
  it("flags two untimed workouts on one day, but not a timed beside an untimed", () => {
    expect(findConflicts(occ, [ex("2026-09-29", null)])).toHaveLength(1);
    expect(findConflicts(occ, [ex("2026-09-29", "18:00")])).toHaveLength(0);
    expect(findConflicts(occ, [ex("2026-09-28", null)])).toHaveLength(0);
  });
  it("ignores cancelled sessions and other days", () => {
    expect(findConflicts(occ, [ex("2026-09-28", "18:00", "CANCELLED"), ex("2026-09-30", "18:00")])).toHaveLength(0);
  });
  it("reports each program workout at most once", () => {
    expect(findConflicts(occ, [ex("2026-09-28", "18:10"), ex("2026-09-28", "18:20")])).toHaveLength(1);
  });
});

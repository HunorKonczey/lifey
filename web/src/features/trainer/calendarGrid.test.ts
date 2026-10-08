import { describe, expect, it } from "vitest";
import { bucketSessions, buildHourRows, dropAction, gapKey, isSameSlot, moveBody, moveDateProblem, occupiedHours, sessionHour, slotFromInput } from "./calendarGrid";
import type { TrainerCalendarSessionResponse } from "./types";

const s = (id: number, scheduledFor: string, scheduledTime: string | null): TrainerCalendarSessionResponse => ({
  sessionId: id,
  clientId: 1,
  clientEmail: "a@x.hu",
  scheduledFor,
  scheduledTime,
  templateName: "Láb",
  status: "UPCOMING",
  scheduleId: 1,
  programAssignmentId: null,
  programName: null,
});

describe("sessionHour", () => {
  it("reads the hour from HH:mm and HH:mm:ss, and is null without a time", () => {
    expect(sessionHour({ scheduledTime: "18:00" })).toBe(18);
    expect(sessionHour({ scheduledTime: "07:30:00" })).toBe(7);
    expect(sessionHour({ scheduledTime: null })).toBeNull();
  });
});

describe("bucketSessions", () => {
  it("buckets timed sessions by day and hour, untimed ones by day, ordered by time", () => {
    const { cells, untimed } = bucketSessions([s(1, "2026-09-29", "18:30"), s(2, "2026-09-29", "18:00"), s(3, "2026-09-29", null), s(4, "2026-09-30", "07:15")]);
    expect(cells.get("2026-09-29|18")?.map((x) => x.sessionId)).toEqual([2, 1]);
    expect(cells.get("2026-09-30|7")?.map((x) => x.sessionId)).toEqual([4]);
    expect(untimed.get("2026-09-29")?.map((x) => x.sessionId)).toEqual([3]);
  });
});

describe("buildHourRows", () => {
  it("folds a long empty run into one gap row and keeps the occupied hours", () => {
    const rows = buildHourRows(new Set([8, 9, 16, 18]));
    expect(rows).toEqual([
      { kind: "hour", hour: 7 },
      { kind: "hour", hour: 8 },
      { kind: "hour", hour: 9 },
      { kind: "gap", from: 10, to: 15 },
      { kind: "hour", hour: 16 },
      { kind: "hour", hour: 17 },
      { kind: "hour", hour: 18 },
      { kind: "hour", hour: 19 },
      { kind: "hour", hour: 20 },
    ]);
  });
  it("leaves short empty runs as rows", () => {
    const rows = buildHourRows(new Set([8, 11, 14, 17, 20]));
    expect(rows.filter((r) => r.kind === "gap")).toEqual([]);
  });
  it("shows a folded run when it is expanded", () => {
    const rows = buildHourRows(new Set([8]), { expanded: new Set([gapKey(9, 20)]) });
    expect(rows.some((r) => r.kind === "gap")).toBe(false);
    expect(rows).toHaveLength(14);
  });
  it("widens the range for a session outside 07:00–20:00", () => {
    const rows = buildHourRows(new Set([5, 22]));
    expect(rows[0]).toEqual({ kind: "hour", hour: 5 });
    expect(rows[rows.length - 1]).toEqual({ kind: "hour", hour: 22 });
  });
  it("with nothing at all folds the whole day into one run", () => {
    expect(buildHourRows(new Set())).toEqual([{ kind: "gap", from: 7, to: 20 }]);
  });
});

describe("occupiedHours", () => {
  it("collects the hours of timed sessions only", () => {
    expect([...occupiedHours([s(1, "2026-09-29", "18:00"), s(2, "2026-09-30", "18:30"), s(3, "2026-09-30", null)])]).toEqual([18]);
  });
});

describe("dropAction / moveBody", () => {
  it("is a no-op onto the same day and hour, and for an untimed event onto the no-time row of its day", () => {
    expect(dropAction({ scheduledFor: "2026-10-02", scheduledTime: "18:30:00" }, { date: "2026-10-02", time: "18:00" })).toBe("noop");
    expect(dropAction({ scheduledFor: "2026-10-02", scheduledTime: null }, { date: "2026-10-02", time: null })).toBe("noop");
  });
  it("places on another hour, another day, or between timed and untimed", () => {
    expect(dropAction({ scheduledFor: "2026-10-02", scheduledTime: "18:30:00" }, { date: "2026-10-02", time: "19:00" })).toBe("place");
    expect(dropAction({ scheduledFor: "2026-10-02", scheduledTime: "18:30:00" }, { date: "2026-10-03", time: "18:00" })).toBe("place");
    expect(dropAction({ scheduledFor: "2026-10-02", scheduledTime: "18:30:00" }, { date: "2026-10-02", time: null })).toBe("place");
    expect(dropAction({ scheduledFor: "2026-10-02", scheduledTime: null }, { date: "2026-10-02", time: "07:00" })).toBe("place");
  });
  it("builds the move request from the slot", () => {
    expect(moveBody({ date: "2026-10-05", time: "07:00" })).toEqual({ scheduledFor: "2026-10-05", scheduledTime: "07:00" });
    expect(moveBody({ date: "2026-10-05", time: null })).toEqual({ scheduledFor: "2026-10-05", scheduledTime: null });
  });
});

describe("moveDateProblem (the backend's window: today .. today + 3 months)", () => {
  const today = "2026-10-08";
  it("accepts today, a later day and the last day of the window", () => {
    expect(moveDateProblem("2026-10-08", today)).toBeNull();
    expect(moveDateProblem("2026-11-30", today)).toBeNull();
    expect(moveDateProblem("2027-01-08", today)).toBeNull();
  });
  it("rejects the past and anything beyond three months", () => {
    expect(moveDateProblem("2026-10-07", today)).toBe("past");
    expect(moveDateProblem("2027-01-09", today)).toBe("horizon");
  });
  it("rejects a date that is not a full yyyy-MM-dd", () => {
    expect(moveDateProblem("", today)).toBe("invalid");
    expect(moveDateProblem("2026-10-8", today)).toBe("invalid");
    expect(moveDateProblem("2026-13-40", today)).toBe("invalid");
  });
  it("counts calendar months and clamps like Java's plusMonths: 30 Nov + 3 months is 28 Feb, not 2 March", () => {
    expect(moveDateProblem("2027-02-28", "2026-11-30")).toBeNull();
    expect(moveDateProblem("2027-03-01", "2026-11-30")).toBe("horizon");
    expect(moveDateProblem("2027-03-31", "2026-12-31")).toBeNull();
    expect(moveDateProblem("2027-04-01", "2026-12-31")).toBe("horizon");
    expect(moveDateProblem("2028-02-29", "2027-11-30")).toBeNull();
  });
});

describe("slotFromInput / isSameSlot", () => {
  it("an empty time is 'no time of day'", () => {
    expect(slotFromInput("2026-10-09", "")).toEqual({ date: "2026-10-09", time: null });
    expect(slotFromInput("2026-10-09", "17:30")).toEqual({ date: "2026-10-09", time: "17:30" });
  });
  it("compares the exact minutes, unlike a drop onto an hour cell", () => {
    const session = { scheduledFor: "2026-10-09", scheduledTime: "17:30:00" };
    expect(isSameSlot(session, { date: "2026-10-09", time: "17:30" })).toBe(true);
    expect(isSameSlot(session, { date: "2026-10-09", time: "17:45" })).toBe(false);
    expect(isSameSlot(session, { date: "2026-10-10", time: "17:30" })).toBe(false);
    expect(isSameSlot(session, { date: "2026-10-09", time: null })).toBe(false);
    expect(isSameSlot({ scheduledFor: "2026-10-09", scheduledTime: null }, { date: "2026-10-09", time: null })).toBe(true);
  });
});

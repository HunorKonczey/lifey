import { describe, expect, it } from "vitest";
import { bucketSessions, buildHourRows, gapKey, occupiedHours, sessionHour } from "./calendarGrid";
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

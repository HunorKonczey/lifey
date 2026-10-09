import { describe, expect, it } from "vitest";
import { logDateLabel, weightLogRows, weightTakenAt } from "./logTable";
import type { WeightResponse } from "./types";

const w = (id: number, date: string, weight: number): WeightResponse => ({ id, date, weight });

describe("weightLogRows", () => {
  it("newest first, each with its change against the previous entry in time", () => {
    const rows = weightLogRows([w(1, "2026-09-25", 69.8), w(3, "2026-09-27", 69.6), w(2, "2026-09-26", 69.8)]);
    expect(rows.map((r) => r.entry.id)).toEqual([3, 2, 1]);
    expect(rows.map((r) => r.delta)).toEqual([-0.2, 0, null]);
  });

  it("the change is rounded to one decimal — no floating-point tails", () => {
    const rows = weightLogRows([w(1, "2026-09-26", 69.8), w(2, "2026-09-27", 69.6)]);
    expect(rows[0].delta).toBe(-0.2);
    expect(String(rows[0].delta)).toBe("-0.2");
  });

  it("two entries the same day are ordered by id, the later one compared with the earlier", () => {
    const rows = weightLogRows([w(5, "2026-09-27", 69.0), w(4, "2026-09-27", 69.6)]);
    expect(rows.map((r) => r.entry.id)).toEqual([5, 4]);
    expect(rows[0].delta).toBe(-0.6);
  });

  it("no entries, no rows", () => {
    expect(weightLogRows([])).toEqual([]);
  });
});

describe("logDateLabel", () => {
  const d = new Date(2026, 8, 26);
  it("capitalises the weekday in Hungarian and English", () => {
    expect(logDateLabel(d, "hu", () => "szept. 26.")).toBe("Szombat, szept. 26.");
    expect(logDateLabel(d, "en", () => "Sep 26")).toBe("Saturday, Sep 26");
  });
});

describe("weightTakenAt", () => {
  // Built from local parts so the day comparison holds in any time zone the suite runs in.
  const takenLocal = new Date(2026, 8, 27, 7, 2).toISOString();

  it("is the moment itself when the entry was taken on the day it is for", () => {
    expect(weightTakenAt({ date: "2026-09-27", recordedAt: takenLocal })?.getTime()).toBe(new Date(takenLocal).getTime());
  });

  it("is null for a back-dated entry: logged on another day than the one it is for", () => {
    expect(weightTakenAt({ date: "2026-09-24", recordedAt: takenLocal })).toBeNull();
  });

  it("is null without a time (an older server) or with one that does not parse", () => {
    expect(weightTakenAt({ date: "2026-09-27" })).toBeNull();
    expect(weightTakenAt({ date: "2026-09-27", recordedAt: null })).toBeNull();
    expect(weightTakenAt({ date: "2026-09-27", recordedAt: "not a date" })).toBeNull();
  });
});

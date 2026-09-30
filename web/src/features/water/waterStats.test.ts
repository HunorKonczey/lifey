import { describe, expect, it } from "vitest";
import { containersLeft, waterWindow } from "./waterStats";
import type { WaterEntryResponse } from "./types";

const NOW = new Date(2026, 8, 30, 15, 0); // Wednesday
const e = (id: number, d: Date, hour: number, liters: number): WaterEntryResponse => ({
  id,
  consumedAt: new Date(d.getFullYear(), d.getMonth(), d.getDate(), hour).toISOString(),
  volumeLiters: liters,
  sourceId: null,
  sourceName: null,
});
const ago = (n: number) => new Date(2026, 8, 30 - n);

describe("waterWindow", () => {
  it("14 days ending today, litres per day, today flagged", () => {
    const w = waterWindow([e(1, ago(0), 9, 0.5), e(2, ago(0), 12, 0.3), e(3, ago(1), 10, 2.6)], 2.5, NOW, NOW);
    expect(w.days).toHaveLength(14);
    expect(w.days[13].isToday).toBe(true);
    expect(w.days[13].liters).toBeCloseTo(0.8, 5);
    expect(w.days[12].liters).toBe(2.6);
    expect(w.days[12].met).toBe(true);
    expect(w.days[0].liters).toBe(0);
  });

  it("the average and the met days leave today out: 13 complete days", () => {
    const entries = [e(1, ago(0), 9, 9), e(2, ago(1), 9, 3), e(3, ago(2), 9, 2), e(4, ago(3), 9, 2.5)];
    const w = waterWindow(entries, 2.5, NOW, NOW);
    expect(w.completeDays).toBe(13);
    expect(w.metDays).toBe(2); // 3 and 2.5; today's 9 L does not count
    expect(w.average).toBeCloseTo((3 + 2 + 2.5) / 3, 5); // only days with something logged
  });

  it("a day of 0,1 + 0,2 litres meets a 0,3 goal (no floating-point miss)", () => {
    const w = waterWindow([e(1, ago(1), 9, 0.1), e(2, ago(1), 10, 0.2)], 0.3, NOW, NOW);
    expect(w.days[12].met).toBe(true);
  });

  it("no entries: no average, nothing met", () => {
    const w = waterWindow([], 2.5, NOW, NOW);
    expect(w.average).toBeNull();
    expect(w.metDays).toBe(0);
  });

  it("a window ending on a past day has no today in it: 14 complete days", () => {
    const w = waterWindow([e(1, ago(3), 9, 3)], 2.5, ago(2), NOW);
    expect(w.days.some((d) => d.isToday)).toBe(false);
    expect(w.completeDays).toBe(14);
    expect(w.metDays).toBe(1);
  });
});

describe("containersLeft", () => {
  it("rounds to the nearest container, never 0 while something is left", () => {
    expect(containersLeft(0.9, 0.25)).toBe(4);
    expect(containersLeft(0.05, 0.25)).toBe(1);
    expect(containersLeft(0, 0.25)).toBe(0);
    expect(containersLeft(-1, 0.25)).toBe(0);
  });

  it("falls back to a 0,25 L container for a nonsense size", () => {
    expect(containersLeft(0.5, 0)).toBe(2);
  });
});

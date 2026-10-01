import { describe, expect, it } from "vitest";
import { stepsWindow } from "./stats";
import type { DailyStepCountResponse } from "./types";

const NOW = new Date(2026, 8, 27, 15, 0); // Sunday 27 Sep
const s = (id: number, daysAgo: number, steps: number): DailyStepCountResponse => {
  const d = new Date(2026, 8, 27 - daysAgo);
  return { id, date: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`, steps };
};

describe("stepsWindow", () => {
  it("14 days ending today, steps per day, today flagged", () => {
    const w = stepsWindow([s(1, 0, 6412), s(2, 1, 9500)], 9000, NOW, NOW);
    expect(w.days).toHaveLength(14);
    expect(w.days[13]).toMatchObject({ steps: 6412, isToday: true, met: false });
    expect(w.days[12]).toMatchObject({ steps: 9500, isToday: false, met: true });
    expect(w.days[0].steps).toBe(0);
  });

  it("the average and the met days leave today out: 13 complete days", () => {
    const entries = [s(1, 0, 20000), s(2, 1, 12000), s(3, 2, 8000), s(4, 3, 9000), s(5, 4, 4000)];
    const w = stepsWindow(entries, 9000, NOW, NOW);
    expect(w.completeDays).toBe(13);
    expect(w.metDays).toBe(2); // 12 000 and 9 000 — today's 20 000 does not count
    expect(w.average).toBeCloseTo((12000 + 8000 + 9000 + 4000) / 4, 5);
  });

  it("days with nothing recorded are not zeros in the average", () => {
    const w = stepsWindow([s(1, 1, 10000), s(2, 5, 6000)], 9000, NOW, NOW);
    expect(w.average).toBe(8000);
  });

  it("the best day looks at the whole window, today included", () => {
    const w = stepsWindow([s(1, 0, 14000), s(2, 6, 12480)], 9000, NOW, NOW);
    expect(w.best?.steps).toBe(14000);
    const w2 = stepsWindow([s(1, 0, 3000), s(2, 6, 12480)], 9000, NOW, NOW);
    expect(w2.best).toEqual({ date: new Date(2026, 8, 21), steps: 12480 });
  });

  it("exactly the goal counts as met", () => {
    expect(stepsWindow([s(1, 1, 9000)], 9000, NOW, NOW).metDays).toBe(1);
  });

  it("no counts: no average, no best, nothing met", () => {
    const w = stepsWindow([], 9000, NOW, NOW);
    expect(w.average).toBeNull();
    expect(w.best).toBeNull();
    expect(w.metDays).toBe(0);
  });

  it("a window ending on a past day has no today in it: 14 complete days", () => {
    const w = stepsWindow([s(1, 3, 10000)], 9000, new Date(2026, 8, 25), NOW);
    expect(w.days.some((d) => d.isToday)).toBe(false);
    expect(w.completeDays).toBe(14);
  });
});

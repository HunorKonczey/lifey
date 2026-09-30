import { describe, expect, it } from "vitest";
import { buildWeightSeries, mondayOf, weeklyMeans } from "./weightSeries";
import type { WeightResponse } from "./types";

const w = (id: number, date: string, weight: number): WeightResponse => ({ id, date, weight });
const NOW = new Date(2026, 8, 27, 12); // Sunday 27 Sep 2026

describe("mondayOf", () => {
  it("the Monday of the week, Sunday included", () => {
    expect(mondayOf(new Date(2026, 8, 27))).toEqual(new Date(2026, 8, 21));
    expect(mondayOf(new Date(2026, 8, 21, 23, 59))).toEqual(new Date(2026, 8, 21));
  });
});

describe("weeklyMeans", () => {
  it("averages each week and leaves an empty week as a gap", () => {
    const pts = [
      { date: new Date(2026, 8, 7), value: 70 }, // week of 7 Sep
      { date: new Date(2026, 8, 9), value: 69 },
      { date: new Date(2026, 8, 22), value: 68 }, // week of 21 Sep; 14 Sep has nothing
    ];
    const weeks = weeklyMeans(pts, new Date(2026, 8, 7), new Date(2026, 8, 27));
    expect(weeks.map((x) => x.value)).toEqual([69.5, null, 68]);
    expect(weeks[0].weekStart).toEqual(new Date(2026, 8, 7));
  });

  it("whole weeks at both ends, and points outside are ignored", () => {
    const pts = [{ date: new Date(2026, 8, 1), value: 99 }, { date: new Date(2026, 8, 24), value: 70 }];
    const weeks = weeklyMeans(pts, new Date(2026, 8, 23), new Date(2026, 8, 27));
    expect(weeks).toHaveLength(1);
    expect(weeks[0].value).toBe(70);
  });
});

describe("buildWeightSeries", () => {
  const weights = [w(1, "2026-08-18", 72), w(2, "2026-09-10", 70.5), w(3, "2026-09-25", 69.8), w(4, "2026-09-27", 69.6)];

  it("30 days: one point a day ending today, the days without a weigh-in are null", () => {
    const s = buildWeightSeries(weights, "30d", NOW);
    expect(s.weekly).toBe(false);
    expect(s.points).toHaveLength(30);
    expect(s.points[29].date).toEqual(new Date(2026, 8, 27));
    expect(s.points[29].value).toBe(69.6);
    expect(s.points.filter((p) => p.value != null)).toHaveLength(3); // 18 Aug is outside the 30 days
    expect(s.points[28].value).toBeNull();
  });

  it("90 days reaches the first weigh-in", () => {
    const s = buildWeightSeries(weights, "90d", NOW);
    expect(s.points).toHaveLength(90);
    expect(s.points.filter((p) => p.value != null)).toHaveLength(4);
  });

  it("1 year is weekly means over 52 weeks, most of them empty here", () => {
    const s = buildWeightSeries(weights, "1y", NOW);
    expect(s.weekly).toBe(true);
    expect(s.points.length).toBeGreaterThanOrEqual(52);
    expect(s.points.filter((p) => p.value != null)).toHaveLength(3); // the weeks of 17 Aug, 7 Sep and 21 Sep
    // the week of 21 Sep averages 25 and 27 Sep
    const last = s.points[s.points.length - 1];
    expect(last.date).toEqual(new Date(2026, 8, 21));
    expect(last.value).toBeCloseTo((69.8 + 69.6) / 2, 5);
  });

  it("all: daily while the history is short, weekly once it is longer than 120 days", () => {
    expect(buildWeightSeries(weights, "all", NOW).weekly).toBe(false);
    expect(buildWeightSeries(weights, "all", NOW).points).toHaveLength(41); // 18 Aug … 27 Sep
    const old = [w(0, "2026-01-05", 75), ...weights];
    expect(buildWeightSeries(old, "all", NOW).weekly).toBe(true);
  });

  it("no weigh-ins, no series", () => {
    expect(buildWeightSeries([], "30d", NOW)).toEqual({ points: [], weekly: false });
  });
});

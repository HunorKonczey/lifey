import { describe, expect, it } from "vitest";
import {
  averageExcludingPartialToday,
  movingAverage,
  niceAxisMax,
  weekStart,
  weeklyBuckets,
  yAxisTicks,
  type DayValue,
  type TimeSeriesPoint,
} from "./chartMath";

// Test cases ported verbatim from mobile/test/shared/widgets/charts/bar_chart_test.dart
// and mobile/test/features/statistics/domain/metric_summary_test.dart.

describe("niceAxisMax", () => {
  it("rounds up to two significant digits", () => {
    expect(niceAxisMax(2360)).toBe(2400); // dashboard goal
    expect(niceAxisMax(12612)).toBe(13000); // stats steps
    expect(niceAxisMax(99.5)).toBe(100);
    expect(niceAxisMax(1000)).toBe(1000);
    expect(niceAxisMax(0.83)).toBeCloseTo(0.83, 9);
  });

  it("gives small integer counts one step of headroom", () => {
    expect(niceAxisMax(6, { integer: true })).toBe(7); // stats workouts
    expect(niceAxisMax(1, { integer: true })).toBe(2);
    expect(niceAxisMax(12, { integer: true })).toBe(12);
  });

  it("still has an axis for an empty chart", () => {
    expect(niceAxisMax(0)).toBe(1);
    expect(niceAxisMax(NaN)).toBe(1);
  });
});

describe("yAxisTicks", () => {
  it("counts the goal toward the axis top", () => {
    expect(yAxisTicks(1910, { goal: 2360 })).toEqual([2400, 1200, 0]);
    expect(yAxisTicks(0, { goal: 2360 })).toEqual([2400, 1200, 0]);
  });

  it("keeps the half exact, not rounded", () => {
    expect(yAxisTicks(6, { integer: true })).toEqual([7, 3.5, 0]);
    expect(yAxisTicks(12612)).toEqual([13000, 6500, 0]);
  });
});

describe("averageExcludingPartialToday (plan §9 risk 5)", () => {
  const now = new Date(2026, 8, 24, 8, 30); // Sep 24 2026, 08:30
  const d = (daysAgo: number, value: number | null): DayValue => ({
    day: new Date(2026, 8, 24 - daysAgo, 13),
    value,
  });

  it("leaves out today's half-logged day", () => {
    const avg = averageExcludingPartialToday([d(2, 1800), d(1, 2000), d(0, 300)], now);
    expect(avg).toBe(1900);
  });

  it("skips missing days; zeros only count out with ignoreZero", () => {
    const points = [d(3, 1800), d(2, null), d(1, 0)];
    expect(averageExcludingPartialToday(points, now)).toBe(900);
    expect(averageExcludingPartialToday(points, now, { ignoreZero: true })).toBe(1800);
  });

  it("gives no average rather than a misleading one when only today has a value", () => {
    expect(averageExcludingPartialToday([d(0, 621)], now)).toBeNull();
  });

  it("treats a value logged at 00:10 today as still today", () => {
    const points: DayValue[] = [{ day: new Date(2026, 8, 24, 0, 10), value: 500 }, d(1, 1500)];
    expect(averageExcludingPartialToday(points, now)).toBe(1500);
  });
});

describe("weekStart", () => {
  it("is a Monday, across a month and a year end", () => {
    expect(weekStart(new Date(2026, 8, 24))).toEqual(new Date(2026, 8, 21));
    expect(weekStart(new Date(2026, 8, 21))).toEqual(new Date(2026, 8, 21));
    expect(weekStart(new Date(2026, 8, 20))).toEqual(new Date(2026, 8, 14));
    expect(weekStart(new Date(2026, 0, 1))).toEqual(new Date(2025, 11, 29));
  });
});

describe("weeklyBuckets", () => {
  it("buckets into calendar weeks Monday to Sunday, empty ones as zero, ends whole", () => {
    const points: TimeSeriesPoint[] = [
      { date: new Date(2026, 8, 2), value: 1 }, // week of Aug 31
      { date: new Date(2026, 8, 3), value: 2 }, // week of Aug 31
      { date: new Date(2026, 8, 21), value: 4 }, // week of Sep 21
      { date: new Date(2026, 8, 24), value: 1 }, // week of Sep 21
    ];

    const weeks = weeklyBuckets(points, new Date(2026, 8, 2), new Date(2026, 8, 24));

    expect(weeks.map((w) => w.weekStart)).toEqual([
      new Date(2026, 7, 31),
      new Date(2026, 8, 7),
      new Date(2026, 8, 14),
      new Date(2026, 8, 21),
    ]);
    expect(weeks.map((w) => w.value)).toEqual([3, 0, 0, 5]);
  });
});

describe("movingAverage", () => {
  const day = (n: number, value: number): TimeSeriesPoint => ({ date: new Date(2026, 8, n), value });

  it("is null until the window has at least 2 entries", () => {
    const trend = movingAverage([day(1, 70)]);
    expect(trend).toEqual([null]);
  });

  it("averages only the entries within the trailing window, not by sample count", () => {
    // Day 1 and day 20 are 19 days apart — far outside a 7-day window, so day
    // 20's trend point is null despite there being a "previous" sample.
    const trend = movingAverage([day(1, 70), day(20, 68)]);
    expect(trend).toEqual([null, null]);
  });

  it("averages consecutive days inside the window", () => {
    const points = [day(1, 70), day(2, 72), day(3, 71)];
    const trend = movingAverage(points);
    expect(trend[0]).toBeNull();
    expect(trend[1]).toBeCloseTo(71); // (70+72)/2
    expect(trend[2]).toBeCloseTo(71); // (70+72+71)/3
  });
});

import { describe, expect, it } from "vitest";
import {
  GOAL_REACHED_TOLERANCE_KG,
  movingAverage,
  projectGoal,
  sinceStart,
  weeklyPace,
  weightPoints,
  type TimeSeriesPoint,
} from "./trend";

/**
 * The cases of `mobile/test/features/weight/domain/weight_trend_test.dart`,
 * ported one for one (W1.6: "the mobile test cases pass unchanged in TS") —
 * the window rule, the two-entry rule and every state the goal card can be
 * in — plus the web-only helpers at the end.
 */

const p = (dayOffset: number, value: number): TimeSeriesPoint => ({ date: new Date(2026, 2, 1 + dayOffset), value });

/** A straight line of daily weigh-ins, `kgPerDay` apart. */
const daily = (days: number, { from = 90, kgPerDay = 0 } = {}): TimeSeriesPoint[] =>
  Array.from({ length: days }, (_, i) => p(i, from + kgPerDay * i));

describe("movingAverage", () => {
  it("averages the trailing 7 days, not the trailing 7 entries", () => {
    // Two entries three weeks apart: the later one has an empty window behind it.
    expect(movingAverage([p(0, 100), p(21, 90)])).toEqual([null, null]);
  });

  it("a window with a single entry has nothing to average", () => {
    expect(movingAverage([p(0, 80)])).toEqual([null]);
  });

  it("smooths a daily series over its window", () => {
    const trend = movingAverage([p(0, 80), p(1, 82), p(2, 81)]);
    expect(trend[0]).toBeNull();
    expect(trend[1]).toBe(81);
    expect(trend[2]).toBeCloseTo(81, 3);
  });

  it("drops entries as they fall out of the window", () => {
    const trend = movingAverage(daily(10, { from: 80, kgPerDay: 1 }));
    // Day 9 averages days 3..9 only — 83..89.
    expect(trend[trend.length - 1]).toBeCloseTo(86, 3);
  });

  it("a gap breaks the trend rather than bridging it", () => {
    const trend = movingAverage([p(0, 80), p(1, 81), p(30, 78), p(31, 77)]);
    expect(trend[1]).not.toBeNull();
    expect(trend[2]).toBeNull(); // first day after the gap stands alone
    expect(trend[3]).not.toBeNull();
  });

  it("measures the window in calendar days across a daylight-saving change", () => {
    // 2026-03-29 is when Europe springs forward; a window spanning it must
    // still hold exactly 7 calendar days (the 1st..7th of a daily series
    // crossing the change would lose or keep a day if it used 24h steps).
    const points = Array.from({ length: 10 }, (_, i) => ({ date: new Date(2026, 2, 25 + i), value: 80 + i }));
    const trend = movingAverage(points);
    // 3rd April = index 9 → averages 28 Mar .. 3 Apr = 83..89 → 86
    expect(trend[9]).toBeCloseTo(86, 3);
  });
});

describe("projectGoal", () => {
  const project = (points: TimeSeriesPoint[], goal: number) =>
    projectGoal({ points, trend: movingAverage(points), goalKg: goal, now: new Date(2026, 2, 1 + 40) });

  it("names a date when the trend moves toward the goal", () => {
    // 100 g/day down for 30 days, goal 5 kg below the current trend.
    const projection = project(daily(30, { from: 90, kgPerDay: -0.1 }), 82)!;

    expect(projection.state).toBe("onTrack");
    // Slightly flatter than the raw 0.7 kg/week: the first trend values average a partial window.
    expect(projection.kgPerWeek).toBeCloseTo(-0.7, 1);
    // The trend trails the raw line by about three days of loss: 87.4 - 82.
    expect(projection.remainingKg).toBeCloseTo(5.4, 0);
    expect(projection.currentKg - projection.goalKg).toBeCloseTo(projection.remainingKg, 3);
    // 5.4 kg left at ~0.1 kg/day.
    const days = Math.round((projection.etaDate!.getTime() - new Date(2026, 2, 41).getTime()) / 86_400_000);
    expect(Math.abs(days - 56)).toBeLessThanOrEqual(5);
  });

  it("reads the trend, not the last noisy weigh-in", () => {
    const points = [...daily(29, { from: 90, kgPerDay: -0.1 }), p(29, 95)];
    const projection = project(points, 80)!;
    // The raw series ends at 95 kg and the trend behind it around 87.5.
    expect(projection.currentKg).toBeLessThan(89);
    expect(projection.currentKg).toBeGreaterThan(87);
  });

  it("says so instead of guessing from a fortnight of nothing", () => {
    const projection = project(daily(6, { from: 90, kgPerDay: -0.1 }), 80)!;
    expect(projection.state).toBe("notEnoughData");
    expect(projection.kgPerWeek).toBeUndefined();
  });

  it("flags a trend moving away from the goal", () => {
    const projection = project(daily(30, { from: 90, kgPerDay: 0.1 }), 80)!;
    expect(projection.state).toBe("wrongWay");
    expect(projection.kgPerWeek).toBeCloseTo(0.7, 1);
    expect(projection.etaDate).toBeUndefined();
  });

  it("a flat trend is not a slow one — it never arrives", () => {
    expect(project(daily(30, { from: 90 }), 80)!.state).toBe("wrongWay");
  });

  it("refuses an estimate further out than two years", () => {
    // 1 g/day against a 10 kg gap — ~27 years.
    const projection = project(daily(30, { from: 90, kgPerDay: -0.001 }), 80)!;
    expect(projection.state).toBe("tooSlow");
    expect(projection.etaDate).toBeUndefined();
  });

  it("recognizes the goal as reached within the tolerance", () => {
    const projection = project(daily(30, { from: 80.1 }), 80)!;
    expect(projection.state).toBe("reached");
    expect(projection.remainingKg).toBeLessThanOrEqual(GOAL_REACHED_TOLERANCE_KG);
  });

  it("gaining toward a higher goal counts as on track", () => {
    const projection = project(daily(30, { from: 60, kgPerDay: 0.05 }), 65)!;
    expect(projection.state).toBe("onTrack");
    expect(projection.kgPerWeek!).toBeGreaterThan(0);
  });

  it("nothing to project from yields null", () => {
    expect(projectGoal({ points: [], trend: [], goalKg: 80 })).toBeNull();
    expect(project([p(0, 90)], 80)).toBeNull(); // no trend value yet
  });
});

describe("weeklyPace", () => {
  it("is the trend's slope per week, signed like the scale", () => {
    const points = daily(30, { from: 90, kgPerDay: -0.1 });
    expect(weeklyPace(points, movingAverage(points))).toBeCloseTo(-0.7, 1);
    const gaining = daily(30, { from: 60, kgPerDay: 0.05 });
    expect(weeklyPace(gaining, movingAverage(gaining))!).toBeGreaterThan(0);
  });

  it("is null while there isn't enough trend — under 4 points or under 14 days", () => {
    const short = daily(6, { from: 90, kgPerDay: -0.1 });
    expect(weeklyPace(short, movingAverage(short))).toBeNull();
    expect(weeklyPace([], [])).toBeNull();
  });

  it("agrees with projectGoal's rate for the same data", () => {
    const points = daily(30, { from: 90, kgPerDay: -0.1 });
    const trend = movingAverage(points);
    expect(weeklyPace(points, trend)).toBe(projectGoal({ points, trend, goalKg: 82, now: new Date(2026, 3, 10) })!.kgPerWeek);
  });
});

describe("sinceStart", () => {
  it("is latest minus first", () => {
    expect(sinceStart([p(0, 92), p(10, 90.5), p(20, 89)])).toBeCloseTo(-3, 6);
  });
  it("is null with fewer than two points", () => {
    expect(sinceStart([p(0, 92)])).toBeNull();
    expect(sinceStart([])).toBeNull();
  });
});

describe("weightPoints", () => {
  it("sorts oldest first and turns API dates into local midnights", () => {
    const pts = weightPoints([
      { id: 2, date: "2026-09-27", weight: 69.6 },
      { id: 1, date: "2026-09-25", weight: 70 },
    ]);
    expect(pts.map((x) => x.value)).toEqual([70, 69.6]);
    expect(pts[0].date.getFullYear()).toBe(2026);
    expect(pts[0].date.getMonth()).toBe(8);
    expect(pts[0].date.getDate()).toBe(25);
    expect(pts[0].date.getHours()).toBe(0);
  });

  it("keeps one point per day", () => {
    const pts = weightPoints([
      { id: 1, date: "2026-09-25", weight: 70 },
      { id: 2, date: "2026-09-25", weight: 69.8 },
    ]);
    expect(pts).toHaveLength(1);
  });
});

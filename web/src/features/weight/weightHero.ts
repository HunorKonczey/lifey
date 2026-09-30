import {
  GOAL_REACHED_TOLERANCE_KG,
  movingAverage,
  parseLocalDate,
  projectGoal,
  sinceStart,
  weeklyPace,
  weightPoints,
  type WeightProjection,
} from "./trend";
import type { WeightResponse } from "./types";

export interface WeightHeroData {
  /** The newest weigh-in — the big number. */
  latest: { date: Date; weight: number };
  /** Latest minus the last entry on or before a week earlier; null while no entry is that old (first week of data). */
  weekDelta: number | null;
  /** The first weigh-in ever: "−2,4 kg aug. 18. óta". */
  start: { date: Date; weight: number };
  /** Latest minus the first weigh-in; null with a single entry. */
  sinceStart: number | null;
  goalKg: number | null;
  /** Always non-negative; null without a goal. */
  remainingKg: number | null;
  /** True when within the tolerance of the goal. */
  reached: boolean;
  /** Where the latest weight sits between start (0) and goal (1), clamped; null without a goal or when start = goal. */
  progress: number | null;
  /** The trend's projection (W1.6) — null without a goal or without any trend. */
  projection: WeightProjection | null;
  /** The newest 7-day mean; null while no window has two entries. */
  average7: number | null;
  /** The trend's kg per week, signed like the scale; null while there is not enough data. */
  pace: number | null;
}

const dayNumber = (d: Date) => Math.round(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86_400_000);

/**
 * Everything the weight hero (W4.1, W4-A) shows, from the weigh-ins and the goal. Pure, over the trend helpers of
 * W1.6, so the page and the dashboard name the same pace and date. Null for a fresh account — the page shows the
 * empty state instead. `now` only feeds the projection's date.
 */
export function buildWeightHero(weights: WeightResponse[], goalKg: number | null, now: Date): WeightHeroData | null {
  const points = weightPoints(weights);
  if (points.length === 0) return null;

  const first = points[0];
  const last = points[points.length - 1];
  const trend = movingAverage(points);

  // Change over the last week: against the newest entry that is at least 7 days older than the latest one.
  const weekAgo = dayNumber(last.date) - 7;
  const base = [...points].reverse().find((p) => dayNumber(p.date) <= weekAgo);
  const weekDelta = base ? last.value - base.value : null;

  const remainingKg = goalKg == null ? null : Math.abs(last.value - goalKg);
  const reached = remainingKg != null && remainingKg <= GOAL_REACHED_TOLERANCE_KG;
  const span = goalKg == null ? 0 : first.value - goalKg;
  const progress = goalKg == null || span === 0 ? null : Math.min(1, Math.max(0, (first.value - last.value) / span));

  return {
    latest: { date: last.date, weight: last.value },
    weekDelta,
    start: { date: first.date, weight: first.value },
    sinceStart: sinceStart(points),
    goalKg,
    remainingKg,
    reached,
    progress,
    projection: goalKg == null ? null : projectGoal({ points, trend, goalKg, now }),
    average7: [...trend].reverse().find((v) => v != null) ?? null,
    pace: weeklyPace(points, trend),
  };
}

/** Which third of its month a date falls in — "dec. közepére" / "by mid Dec". */
export function monthThird(date: Date): "early" | "mid" | "late" {
  const d = date.getDate();
  return d <= 10 ? "early" : d <= 20 ? "mid" : "late";
}

export { parseLocalDate };

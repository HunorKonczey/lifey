import type { LineChartPoint } from "@/components/ds/charts/LifeyLineChart";
import { parseLocalDate, weightPoints } from "./trend";
import type { WeightResponse } from "./types";

/** The range switcher of the weight page (W4.2): 30 nap · 90 nap · 1 év · Mind. */
export const WEIGHT_RANGES = ["30d", "90d", "1y", "all"] as const;
export type WeightRange = (typeof WEIGHT_RANGES)[number];

/** Beyond this many days an "all" chart averages by week instead of drawing a dot a day. */
const ALL_DAILY_LIMIT_DAYS = 120;

export interface WeightSeries {
  /** One point per day (null = no weigh-in, a gap) or per week (the week's mean; null = nothing that week). */
  points: LineChartPoint[];
  /** True when the points are weekly means — the 7-day average is then the series itself and is not drawn again. */
  weekly: boolean;
}

const dayMs = 86_400_000;
const day = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
const addDays = (d: Date, n: number) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
const daysBetween = (a: Date, b: Date) => Math.round((Date.UTC(b.getFullYear(), b.getMonth(), b.getDate()) - Date.UTC(a.getFullYear(), a.getMonth(), a.getDate())) / dayMs);

/** Monday of the week containing `d`, local midnight. */
export function mondayOf(d: Date): Date {
  const x = day(d);
  return addDays(x, -((x.getDay() + 6) % 7));
}

/**
 * The mean weight of every Monday-based week from the week of `from` to the week of `to`, oldest first; a week with
 * no weigh-in is a null, not an invented value (W4.2: "gaps stay gaps"). The date on each point is the week's Monday.
 */
export function weeklyMeans(points: { date: Date; value: number }[], from: Date, to: Date): { weekStart: Date; value: number | null }[] {
  const first = mondayOf(from);
  const last = mondayOf(to);
  const sums = new Map<number, { sum: number; n: number }>();
  for (const p of points) {
    const key = mondayOf(p.date).getTime();
    if (key < first.getTime() || key > last.getTime()) continue;
    const e = sums.get(key) ?? { sum: 0, n: 0 };
    e.sum += p.value;
    e.n += 1;
    sums.set(key, e);
  }
  const weeks: { weekStart: Date; value: number | null }[] = [];
  for (let w = first; w.getTime() <= last.getTime(); w = addDays(w, 7)) {
    const e = sums.get(w.getTime());
    weeks.push({ weekStart: w, value: e ? e.sum / e.n : null });
  }
  return weeks;
}

/**
 * The chart's series for a range, ending today. 30 / 90 days: one point per day with gaps as nulls. 1 year: weekly
 * means over the last 52 weeks. All: from the first weigh-in — daily while that is at most 120 days, weekly beyond.
 * `label` of each point is left to the caller (it knows the language and "today"), so this stays pure.
 */
export function buildWeightSeries(weights: WeightResponse[], range: WeightRange, now: Date): WeightSeries {
  const points = weightPoints(weights);
  const today = day(now);
  if (points.length === 0) return { points: [], weekly: false };

  const firstDay = points[0].date;
  let from: Date;
  let weekly = false;
  if (range === "30d") from = addDays(today, -29);
  else if (range === "90d") from = addDays(today, -89);
  else if (range === "1y") {
    from = addDays(today, -364);
    weekly = true;
  } else {
    from = firstDay;
    weekly = daysBetween(firstDay, today) > ALL_DAILY_LIMIT_DAYS;
  }

  if (weekly) {
    return { points: weeklyMeans(points, from, today).map((w) => ({ date: w.weekStart, value: w.value })), weekly: true };
  }

  const byDay = new Map(points.map((p) => [day(p.date).getTime(), p.value]));
  const n = daysBetween(from, today);
  return {
    points: Array.from({ length: n + 1 }, (_, i) => {
      const date = addDays(from, i);
      return { date, value: byDay.get(date.getTime()) ?? null };
    }),
    weekly: false,
  };
}

export { parseLocalDate };

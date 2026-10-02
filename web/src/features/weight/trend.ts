import type { WeightResponse } from "./types";

/**
 * The 7-day moving average and the goal projection behind it — a port of
 * `mobile/lib/features/weight/domain/weight_trend.dart` (docs/76-smarter-
 * weight-trend-plan.md, W1.6). Pure functions over points the caller already
 * has, so both clients name the same trend, pace and date for the same data.
 * Day arithmetic goes through whole calendar days (`dayNumber`), never
 * `ms / 24h`, so a daylight-saving change can't shift a point across a window
 * edge.
 */

export interface TimeSeriesPoint {
  date: Date;
  value: number;
}

/** How many days of history one trend value averages (D-W1). */
export const TREND_WINDOW_DAYS = 7;
/** Fewer entries than this in a window and there is nothing to average (D-W2). */
export const MIN_ENTRIES_PER_WINDOW = 2;
/** How far back the rate is measured (D-W5). */
export const RATE_WINDOW_DAYS = 28;
/** The projection needs this many trend days, spanning at least `MIN_PROJECTION_SPAN_DAYS` (D-W6). */
export const MIN_PROJECTION_POINTS = 4;
export const MIN_PROJECTION_SPAN_DAYS = 14;
/** Closer than this to the goal and the goal counts as reached. */
export const GOAL_REACHED_TOLERANCE_KG = 0.2;
/** Beyond this the estimate stops being an estimate. */
export const MAX_PROJECTION_DAYS = 730;

/** Whole calendar days since 1970-01-01 for a local date — DST-proof. */
function dayNumber(date: Date): number {
  return Math.round(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / 86_400_000);
}

/** `yyyy-MM-dd` (the API's `LocalDate`) as a local midnight. */
export function parseLocalDate(value: string): Date {
  const [y, m, d] = value.split("-").map(Number);
  return new Date(y, m - 1, d);
}

/** The chart/trend input for the API's weigh-ins, oldest first, one per day
 *  (the last entry wins if a day somehow has several). */
export function weightPoints(weights: WeightResponse[]): TimeSeriesPoint[] {
  const byDay = new Map<string, number>();
  for (const w of [...weights].sort((a, b) => a.date.localeCompare(b.date))) byDay.set(w.date, w.weight);
  return [...byDay.entries()].map(([date, value]) => ({ date: parseLocalDate(date), value }));
}

/**
 * The trailing `windowDays`-day mean for each point, aligned index by index
 * with `points` (oldest first); `null` where the window holds fewer than
 * `MIN_ENTRIES_PER_WINDOW` entries.
 *
 * The window is measured in **days, not samples** (D-W1): people skip
 * weigh-ins, and averaging "the last seven entries" over a gappy month would
 * report a weekly figure covering three weeks.
 */
export function movingAverage(points: TimeSeriesPoint[], windowDays = TREND_WINDOW_DAYS): (number | null)[] {
  return points.map((point, i) => {
    const windowStart = dayNumber(point.date) - (windowDays - 1);
    let sum = 0;
    let count = 0;
    // Points are oldest-first, so walking back stops as soon as we leave the window.
    for (let j = i; j >= 0; j--) {
      if (dayNumber(points[j].date) < windowStart) break;
      sum += points[j].value;
      count++;
    }
    return count >= MIN_ENTRIES_PER_WINDOW ? sum / count : null;
  });
}

/** Why the projection is not naming a date, or that it is. */
export type WeightProjectionState = "onTrack" | "reached" | "wrongWay" | "tooSlow" | "notEnoughData";

/** What the goal card shows. `kgPerWeek` is signed the way the scale moves: negative while losing. */
export interface WeightProjection {
  state: WeightProjectionState;
  goalKg: number;
  /** The trend's latest value — not the last raw weigh-in (D-W4). */
  currentKg: number;
  /** How far the goal still is, always non-negative. */
  remainingKg: number;
  /** Absent only when there was not enough data to measure a rate. */
  kgPerWeek?: number;
  etaDate?: Date;
}

function trendSeries(points: TimeSeriesPoint[], trend: (number | null)[]): TimeSeriesPoint[] {
  const series: TimeSeriesPoint[] = [];
  for (let i = 0; i < points.length && i < trend.length; i++) {
    const v = trend[i];
    if (v != null) series.push({ date: points[i].date, value: v });
  }
  return series;
}

function lastDays(series: TimeSeriesPoint[], days: number): TimeSeriesPoint[] {
  const from = dayNumber(series[series.length - 1].date) - (days - 1);
  return series.filter((p) => dayNumber(p.date) >= from);
}

/** Least-squares slope in kg/day (D-W5) — x is days since the first point. */
function slopePerDay(series: TimeSeriesPoint[]): number {
  const origin = dayNumber(series[0].date);
  const xs = series.map((p) => dayNumber(p.date) - origin);
  const meanX = xs.reduce((a, b) => a + b, 0) / xs.length;
  const meanY = series.reduce((a, p) => a + p.value, 0) / series.length;

  let numerator = 0;
  let denominator = 0;
  for (let i = 0; i < series.length; i++) {
    const dx = xs[i] - meanX;
    numerator += dx * (series[i].value - meanY);
    denominator += dx * dx;
  }
  // Every sample on the same day: no slope to measure.
  return denominator === 0 ? 0 : numerator / denominator;
}

/** The last `RATE_WINDOW_DAYS` of the trend — or null when there aren't enough
 *  points/days to measure a rate from (D-W6). */
function rateWindow(series: TimeSeriesPoint[]): TimeSeriesPoint[] | null {
  if (series.length === 0) return null;
  const recent = lastDays(series, RATE_WINDOW_DAYS);
  const spanDays = dayNumber(recent[recent.length - 1].date) - dayNumber(recent[0].date);
  return recent.length < MIN_PROJECTION_POINTS || spanDays < MIN_PROJECTION_SPAN_DAYS ? null : recent;
}

/**
 * How fast the trend is moving, in kg per week — signed like the scale
 * (negative while losing) — or null while there is not enough trend to say.
 * The dashboard's "−0,4 kg / hét" chip (W1.7); the same least-squares slope
 * and the same data floor as `projectGoal`'s rate.
 */
export function weeklyPace(points: TimeSeriesPoint[], trend: (number | null)[]): number | null {
  const recent = rateWindow(trendSeries(points, trend));
  return recent ? slopePerDay(recent) * 7 : null;
}

/** Latest minus the first weigh-in: how far the whole journey has moved. Null with fewer than two points. */
export function sinceStart(points: TimeSeriesPoint[]): number | null {
  return points.length < 2 ? null : points[points.length - 1].value - points[0].value;
}

/**
 * Projects when `trend` would reach `goalKg`, reading the smoothed series
 * rather than the raw weigh-ins (D-W4). `trend` is `movingAverage`'s output
 * beside the points it was derived from; `null` entries are skipped. Returns
 * null when there is no trend at all — the caller hides the card rather than
 * showing an empty one.
 */
export function projectGoal(opts: {
  points: TimeSeriesPoint[];
  trend: (number | null)[];
  goalKg: number;
  now?: Date;
}): WeightProjection | null {
  const { points, trend, goalKg } = opts;
  const series = trendSeries(points, trend);
  if (series.length === 0) return null;

  const current = series[series.length - 1].value;
  const remaining = Math.abs(current - goalKg);
  const base = { goalKg, currentKg: current, remainingKg: remaining };
  if (remaining <= GOAL_REACHED_TOLERANCE_KG) return { state: "reached", ...base };

  const recent = rateWindow(series);
  if (!recent) return { state: "notEnoughData", ...base };

  const kgPerDay = slopePerDay(recent);
  const kgPerWeek = kgPerDay * 7;
  const towardGoal = goalKg < current ? kgPerDay < 0 : kgPerDay > 0;
  if (!towardGoal || kgPerDay === 0) return { state: "wrongWay", ...base, kgPerWeek };

  const days = Math.ceil(remaining / Math.abs(kgPerDay));
  if (days > MAX_PROJECTION_DAYS) return { state: "tooSlow", ...base, kgPerWeek };

  const from = opts.now ?? new Date();
  return {
    state: "onTrack",
    ...base,
    kgPerWeek,
    etaDate: new Date(from.getFullYear(), from.getMonth(), from.getDate() + days),
  };
}

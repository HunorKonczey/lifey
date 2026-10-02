/**
 * Pure helpers behind the v2 charts (D-W0.9), ported from mobile's
 * `chart_math.dart` (`niceAxisMax`/`yAxisTicks`/`averageExcludingPartialToday`),
 * `features/weight/domain/weight_trend.dart` (`movingAverage`), and
 * `features/statistics/domain/metric_summary.dart` (`weekStart`/`weeklySums`,
 * consolidated here as `weeklyBuckets`). Kept free of chart components so
 * they're unit-tested on their own.
 */

export interface TimeSeriesPoint {
  date: Date;
  value: number;
}

/**
 * The top of a chart's Y axis for data peaking at `max`. Rounds up to two
 * significant digits — 2360 → 2400, 12612 → 13000 — so the three labels
 * (top, half, 0) read cleanly. For `integer` data that peaks below 10
 * (workouts per week) the axis gets one step of headroom, so the tallest bar
 * isn't flush with the top: a peak of 6 gives 7. An empty chart gets 1.
 */
export function niceAxisMax(max: number, { integer = false }: { integer?: boolean } = {}): number {
  if (Number.isNaN(max) || max <= 0) return 1;
  const digits = Math.floor(Math.log(max) / Math.LN10) + 1;
  let step = Math.pow(10, digits - 2);
  if (integer && step < 1) step = 1;
  const top = Math.ceil(max / step) * step;
  if (integer && max < 10 && top === max) return top + step;
  return top;
}

/**
 * The three Y-axis values drawn by the charts, top to bottom: the nice max,
 * its half, and 0. The half is exact (3.5 for 7) — the label formatter
 * decides the decimals. `goal` counts toward the axis top.
 */
export function yAxisTicks(
  dataMax: number,
  { goal, integer = false }: { goal?: number; integer?: boolean } = {},
): [number, number, number] {
  const peak = Math.max(dataMax, goal ?? 0);
  const top = niceAxisMax(peak, { integer });
  return [top, top / 2, 0];
}

export interface DayValue {
  day: Date;
  value: number | null;
}

/**
 * The average of daily values **without today's partial day** — a
 * half-logged today would drag the weekly average down. Days with no value
 * are skipped; with `ignoreZero` so are zero days (for calories a 0 means
 * "nothing logged", not "ate nothing"). Returns `null` when no complete day
 * is left.
 */
export function averageExcludingPartialToday(
  points: DayValue[],
  now: Date,
  { ignoreZero = false }: { ignoreZero?: boolean } = {},
): number | null {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const values: number[] = [];
  for (const p of points) {
    if (p.value == null) continue;
    const day = new Date(p.day.getFullYear(), p.day.getMonth(), p.day.getDate());
    if (day.getTime() >= today.getTime()) continue;
    if (ignoreZero && p.value === 0) continue;
    values.push(p.value);
  }
  if (values.length === 0) return null;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

/** The first day (Monday) of `date`'s calendar week. */
export function weekStart(date: Date): Date {
  const day = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const jsWeekday = day.getDay(); // 0 = Sun .. 6 = Sat
  const isoWeekday = jsWeekday === 0 ? 7 : jsWeekday; // 1 = Mon .. 7 = Sun
  day.setDate(day.getDate() - (isoWeekday - 1));
  return day;
}

export interface WeeklyBucket {
  weekStart: Date;
  value: number;
}

/**
 * Sum per calendar week, oldest first, **including weeks with nothing** — a
 * missing week is a zero, not a gap — from the week of `from` to the week of
 * `to`. The two ends are whole calendar weeks: a week is never cut in half
 * by the range's own edge.
 */
export function weeklyBuckets(points: TimeSeriesPoint[], from: Date, to: Date): WeeklyBucket[] {
  const first = weekStart(from);
  const last = weekStart(to);
  const sums = new Map<number, number>();
  for (const p of points) {
    const key = weekStart(p.date).getTime();
    if (key < first.getTime() || key > last.getTime()) continue;
    sums.set(key, (sums.get(key) ?? 0) + p.value);
  }
  const weeks: WeeklyBucket[] = [];
  for (
    let w = new Date(first);
    w.getTime() <= last.getTime();
    w = new Date(w.getFullYear(), w.getMonth(), w.getDate() + 7)
  ) {
    weeks.push({ weekStart: new Date(w), value: sums.get(w.getTime()) ?? 0 });
  }
  return weeks;
}

export const TREND_WINDOW_DAYS = 7;
export const MIN_ENTRIES_PER_WINDOW = 2;

/**
 * The trailing `windowDays`-day mean for each point, aligned index by index
 * with `points`; `null` where the window holds fewer than
 * `MIN_ENTRIES_PER_WINDOW` entries. The window is measured in **days, not
 * samples**: people skip weigh-ins, and averaging "the last seven entries"
 * over a gappy month would report a weekly figure covering three weeks.
 * `points` must be sorted oldest first.
 */
export function movingAverage(points: TimeSeriesPoint[], windowDays = TREND_WINDOW_DAYS): (number | null)[] {
  const trend: (number | null)[] = new Array(points.length).fill(null);
  for (let i = 0; i < points.length; i++) {
    const windowStart = new Date(points[i].date);
    windowStart.setDate(windowStart.getDate() - (windowDays - 1));
    let sum = 0;
    let count = 0;
    // Points are oldest-first, so walking back stops as soon as we leave the window.
    for (let j = i; j >= 0; j--) {
      if (points[j].date.getTime() < windowStart.getTime()) break;
      sum += points[j].value;
      count++;
    }
    if (count >= MIN_ENTRIES_PER_WINDOW) trend[i] = sum / count;
  }
  return trend;
}

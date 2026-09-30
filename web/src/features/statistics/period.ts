import {
  addMonths,
  addWeeks,
  addYears,
  endOfMonth,
  endOfWeek,
  endOfYear,
  format,
  isValid,
  parse,
  startOfDay,
  startOfMonth,
  startOfWeek,
  startOfYear,
} from "date-fns";

/** The statistics page's three views (W5-A): a calendar week, month or year — never a rolling window. */
export const STATS_PERIODS = ["week", "month", "year"] as const;
export type StatsPeriod = (typeof STATS_PERIODS)[number];

/** The page's state, and exactly what the URL carries: `?period=week&start=2026-09-21`. */
export interface PeriodState {
  period: StatsPeriod;
  /** First day of the period — a Monday, the 1st, or 1 January. */
  start: Date;
}

export interface PeriodRange {
  start: Date;
  /** Last day of the period (inclusive), which may still be in the future for the current one. */
  end: Date;
}

const WEEK = { weekStartsOn: 1 } as const;
const ISO = "yyyy-MM-dd";

export function isStatsPeriod(value: string | null | undefined): value is StatsPeriod {
  return value != null && (STATS_PERIODS as readonly string[]).includes(value);
}

/** The first day of the `period` containing `date`. */
export function periodStart(period: StatsPeriod, date: Date): Date {
  const day = startOfDay(date);
  if (period === "week") return startOfWeek(day, WEEK);
  if (period === "month") return startOfMonth(day);
  return startOfYear(day);
}

export function periodRange(period: StatsPeriod, start: Date): PeriodRange {
  const first = periodStart(period, start);
  if (period === "week") return { start: first, end: startOfDay(endOfWeek(first, WEEK)) };
  if (period === "month") return { start: first, end: startOfDay(endOfMonth(first)) };
  return { start: first, end: startOfDay(endOfYear(first)) };
}

/** The period `steps` away (negative = earlier), still starting on its first day. */
export function shiftPeriod(period: StatsPeriod, start: Date, steps: number): Date {
  const first = periodStart(period, start);
  if (period === "week") return addWeeks(first, steps);
  if (period === "month") return addMonths(first, steps);
  return addYears(first, steps);
}

/** The period right before `start`'s — what every delta compares against. */
export function previousPeriod(period: StatsPeriod, start: Date): PeriodRange {
  return periodRange(period, shiftPeriod(period, start, -1));
}

/** Whether `start`'s period contains `now` — it is still accumulating, so nothing in it is a finished total. */
export function isCurrentPeriod(period: StatsPeriod, start: Date, now: Date): boolean {
  return periodStart(period, start).getTime() === periodStart(period, now).getTime();
}

/** Stepping forward stops at the current period (W5.1) — a future period has nothing to show. */
export function canStepForward(period: StatsPeriod, start: Date, now: Date): boolean {
  return shiftPeriod(period, start, 1).getTime() <= startOfDay(now).getTime();
}

/** The state to show for a URL's query string: anything missing, malformed or in the future falls back to the current period. */
export function parsePeriodState(params: URLSearchParams, now: Date): PeriodState {
  const raw = params.get("period");
  const period: StatsPeriod = isStatsPeriod(raw) ? raw : "week";
  const current = periodStart(period, now);
  const parsed = parse(params.get("start") ?? "", ISO, new Date(0));
  if (!isValid(parsed) || params.get("start") == null) return { period, start: current };
  const start = periodStart(period, parsed);
  return { period, start: start.getTime() > current.getTime() ? current : start };
}

/** The query string for `state`, without the leading `?`. */
export function periodSearch(state: PeriodState): string {
  return `period=${state.period}&start=${format(state.start, ISO)}`;
}

/** Switching the view keeps the viewed day in view: week → month lands on the month containing the week's start. */
export function switchPeriod(state: PeriodState, period: StatsPeriod, now: Date): PeriodState {
  if (period === state.period) return state;
  const start = periodStart(period, state.start);
  const current = periodStart(period, now);
  return { period, start: start.getTime() > current.getTime() ? current : start };
}

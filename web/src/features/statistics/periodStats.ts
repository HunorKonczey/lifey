import { addDays, eachDayOfInterval, format, startOfDay, startOfWeek } from "date-fns";
import { activityFamilyOf } from "@/features/workouts/activityType";
import type { RawData } from "./types";
import { isCurrentPeriod, periodRange, previousPeriod, type PeriodRange, type StatsPeriod } from "./period";

/**
 * The numbers behind the statistics page (W5.2) — every figure and every chart series for one period, shaped so
 * the page can stay honest about what it does not know:
 *
 * - **a missing day is `null`, never 0** — a day without a meal is not a day of zero kcal, a day without a
 *   weigh-in is not a weight of zero; charts draw a gap (or, for volume, a rest-day dot);
 * - **today is partial** — it is drawn, but every *average* leaves it out (a half-logged day would drag the
 *   number down), and a *delta* only ever compares figures that mean the same thing in both periods;
 * - **a delta against nothing is not a delta** — an empty previous period gives `null`, never "+1659";
 * - **the colour of a delta follows what it means** for that metric (good / bad / neutral), not its sign.
 *
 * Pure: no React, no i18n, no `Date.now()` — `now` comes in.
 */

export interface StatsGoals {
  /** Daily kcal goal; null when the user never set one. */
  calories: number | null;
  /** Daily step goal (already defaulted). */
  steps: number;
  /** Goal weight in kg; null when onboarding never asked for one. */
  weightKg: number | null;
}

/** One column of a chart: a day (week / month view) or a calendar week (year view). */
export interface Slot {
  start: Date;
  /** Last day the slot covers, clipped to the period (a year's first and last week are partial). */
  end: Date;
  /** The slot holds today — still accumulating. */
  isCurrent: boolean;
  /** Entirely after today: nothing to draw yet. */
  isFuture: boolean;
}

export type DeltaTone = "good" | "bad" | "neutral";

export interface KpiDelta {
  /** Signed change in the KPI's own unit (kcal to the goal, workouts, km, kg of weight change, …). */
  amount: number;
  /** Signed change as a fraction of the previous figure (0.02 = +2 %); null when the previous figure is 0. */
  percent: number | null;
  tone: DeltaTone;
}

export interface Kpi {
  /** The headline figure; null when the period has nothing to base it on. */
  value: number | null;
  /** The same figure for the previous period — null when that period has no data ("Nincs előző adat"). */
  previous: number | null;
  /** null when there is nothing honest to compare. */
  delta: KpiDelta | null;
}

export type CalorieVerdict = "onTarget" | "over" | "under";

export interface PeriodStats {
  period: StatsPeriod;
  range: PeriodRange;
  previousRange: PeriodRange;
  /** Whether the period still contains today. */
  isCurrent: boolean;
  slots: Slot[];
  kpis: {
    calories: Kpi & { goal: number | null };
    weight: Kpi;
    workouts: Kpi;
    volume: Kpi;
    cardio: Kpi;
    steps: Kpi;
  };
  calories: {
    /** Per slot: kcal of a logged day / the mean kcal of a logged week; null = nothing logged. */
    values: (number | null)[];
    average: number | null;
    /** Days (complete, logged) the average stands on. */
    loggedDays: number;
    goal: number | null;
    /** Year view: the first day anything was logged, for the hatched "Még nem naplóztál" band; null = never. */
    firstLog: Date | null;
    /** Year view: number of leading slots that end before `firstLog`. */
    emptySlotsBefore: number;
    /** The previous period holds no meals at all. */
    previousEmpty: boolean;
  };
  weight: {
    /** Per slot: the day's weight / the week's mean; null = no measurement. */
    values: (number | null)[];
    latest: number | null;
    goal: number | null;
    /** The goal lies outside the chart's own scale (the footnote "A célvonal … a tengely alatt van"). */
    goalOutsideScale: boolean;
    /** Y axis bounds the chart uses: the data's range, widened to the goal only when that costs at most 40 % more height. */
    scale: { min: number; max: number } | null;
  };
  volume: {
    /** Per slot: kg lifted; `rest` marks a finished slot with no workout; a future slot is null. */
    values: (number | null)[];
    rest: boolean[];
    total: number;
  };
  cardio: {
    /** Per slot: km; null where there was none. */
    values: (number | null)[];
    totalKm: number;
    sessions: number;
  };
  steps: {
    /** Per slot: steps of a counted day / mean per counted day for a week; null = no count. */
    values: (number | null)[];
    average: number | null;
    goal: number;
  };
}

const iso = (d: Date) => format(d, "yyyy-MM-dd");
const dayOf = (d: Date | string) => startOfDay(new Date(d));

/** Days in `range`. */
function daysIn(range: PeriodRange): Date[] {
  return eachDayOfInterval({ start: range.start, end: range.end });
}

/** The columns of a period: one per day, or — for a year — one per Monday-to-Sunday week clipped to the year. */
export function buildSlots(period: StatsPeriod, range: PeriodRange, now: Date): Slot[] {
  const today = startOfDay(now);
  const make = (start: Date, end: Date): Slot => ({
    start,
    end,
    isCurrent: start.getTime() <= today.getTime() && end.getTime() >= today.getTime(),
    isFuture: start.getTime() > today.getTime(),
  });
  if (period !== "year") return daysIn(range).map((d) => make(d, d));
  const slots: Slot[] = [];
  for (let monday = startOfWeek(range.start, { weekStartsOn: 1 }); monday.getTime() <= range.end.getTime(); monday = addDays(monday, 7)) {
    const start = monday.getTime() < range.start.getTime() ? range.start : monday;
    const sunday = addDays(monday, 6);
    slots.push(make(start, sunday.getTime() > range.end.getTime() ? range.end : sunday));
  }
  return slots;
}

interface Daily {
  calories: Map<string, number>;
  steps: Map<string, number>;
  volume: Map<string, number>;
  cardioKm: Map<string, number>;
  workouts: Map<string, number>;
  weight: Map<string, number>;
  /** The first day any meal was logged — the year view's "since when". */
  firstMeal: Date | null;
  /** The first day anything at all was recorded; before it a missing workout is not a rest day, it is just before the account. */
  firstData: Date | null;
}

/** Everything bucketed by local day, once. A day without an entry has no key — that is what "missing" means. */
export function bucketByDay(raw: RawData): Daily {
  const calories = new Map<string, number>();
  const steps = new Map<string, number>();
  const volume = new Map<string, number>();
  const cardioKm = new Map<string, number>();
  const workouts = new Map<string, number>();
  const weight = new Map<string, number>();
  let firstMeal: Date | null = null;
  let firstData: Date | null = null;
  const seen = (d: Date) => {
    if (firstData == null || d.getTime() < firstData.getTime()) firstData = d;
  };

  for (const m of raw.meals) {
    const day = dayOf(m.dateTime);
    const key = iso(day);
    calories.set(key, (calories.get(key) ?? 0) + m.entries.reduce((s, e) => s + e.calories, 0));
    if (firstMeal == null || day.getTime() < firstMeal.getTime()) firstMeal = day;
    seen(day);
  }
  for (const w of raw.water) seen(dayOf(w.consumedAt));
  for (const s of raw.steps) {
    if (s.steps > 0) steps.set(s.date, s.steps);
    seen(dayOf(s.date));
  }
  for (const w of raw.weights) {
    weight.set(w.date, w.weight);
    seen(dayOf(w.date));
  }

  for (const session of raw.sessions) {
    const key = iso(dayOf(session.startedAt));
    seen(dayOf(session.startedAt));
    workouts.set(key, (workouts.get(key) ?? 0) + 1);
    for (const set of session.sets) {
      const setKey = iso(dayOf(set.performedAt));
      volume.set(setKey, (volume.get(setKey) ?? 0) + set.weight * set.reps);
    }
    // Cardio distance — DISTANCE + MACHINE families only, the same definition as mobile (docs/cardio/56 §3).
    if (session.sessionKind === "CARDIO" && session.activityType) {
      const family = activityFamilyOf(session.activityType);
      const meters = session.cardio?.distanceMeters;
      if ((family === "DISTANCE" || family === "MACHINE") && meters != null) {
        cardioKm.set(key, (cardioKm.get(key) ?? 0) + meters / 1000);
      }
    }
  }
  return { calories, steps, volume, cardioKm, workouts, weight, firstMeal, firstData };
}

/** Cardio sessions in `range` that contributed a distance — the "2 alkalom" under the cardio chart. */
function distanceSessionsIn(raw: RawData, range: PeriodRange): number {
  return raw.sessions.filter((s) => {
    if (s.sessionKind !== "CARDIO" || !s.activityType || s.cardio?.distanceMeters == null) return false;
    const family = activityFamilyOf(s.activityType);
    if (family !== "DISTANCE" && family !== "MACHINE") return false;
    const day = dayOf(s.startedAt).getTime();
    return day >= range.start.getTime() && day <= range.end.getTime();
  }).length;
}

const sum = (values: number[]) => values.reduce((a, b) => a + b, 0);
const mean = (values: number[]) => (values.length === 0 ? null : sum(values) / values.length);

/** The values of `map` on the days of `range`, optionally leaving today (partial) out. */
function valuesIn(map: Map<string, number>, range: PeriodRange, today: Date, { excludeToday }: { excludeToday: boolean }): number[] {
  const out: number[] = [];
  for (const day of daysIn(range)) {
    if (excludeToday && day.getTime() >= today.getTime()) continue;
    const v = map.get(iso(day));
    if (v != null) out.push(v);
  }
  return out;
}

/** A measurement change over a range: last − first, needing two measurements. */
function weightChange(map: Map<string, number>, range: PeriodRange): number | null {
  const points = daysIn(range)
    .map((d) => map.get(iso(d)))
    .filter((v): v is number => v != null);
  return points.length < 2 ? null : points[points.length - 1] - points[0];
}

/**
 * Whether `amount` is a good, bad or neutral change. `higher` / `lower` name the direction that is good for the
 * metric. A *partial* sum (the current period's running total against a finished one) can only be good or neutral —
 * a lower running total may simply not be done yet.
 */
export function deltaTone(amount: number, direction: "higher" | "lower", { partial = false }: { partial?: boolean } = {}): DeltaTone {
  if (amount === 0) return "neutral";
  const good = direction === "higher" ? amount > 0 : amount < 0;
  if (good) return "good";
  return partial ? "neutral" : "bad";
}

/** Within this share of the goal, an average counts as on target (±10 %). */
export const CALORIE_TOLERANCE = 0.1;

export function calorieVerdict(average: number, goal: number): CalorieVerdict {
  if (Math.abs(average - goal) <= goal * CALORIE_TOLERANCE) return "onTarget";
  return average > goal ? "over" : "under";
}

function compare(current: number | null, previous: number | null, direction: "higher" | "lower", partial: boolean): KpiDelta | null {
  if (current == null || previous == null) return null;
  const amount = current - previous;
  return { amount, percent: previous === 0 ? null : amount / previous, tone: deltaTone(amount, direction, { partial }) };
}

/** Weekly mean of the defined values in a slot, or the single day's value. */
function slotValue(map: Map<string, number>, slot: Slot, today: Date, mode: "sum" | "mean", excludeToday: boolean): number | null {
  if (slot.isFuture) return null;
  const values = valuesIn(map, { start: slot.start, end: slot.end }, today, { excludeToday });
  if (values.length === 0) return null;
  return mode === "sum" ? sum(values) : (mean(values) as number);
}

export interface StatsInput {
  raw: RawData;
  period: StatsPeriod;
  start: Date;
  now: Date;
  goals: StatsGoals;
}

export function buildPeriodStats({ raw, period, start, now, goals }: StatsInput): PeriodStats {
  const today = startOfDay(now);
  const range = periodRange(period, start);
  const previousRange = previousPeriod(period, start);
  const isCurrent = isCurrentPeriod(period, start, now);
  const slots = buildSlots(period, range, now);
  const daily = bucketByDay(raw);
  const weekly = period === "year";

  // ── headline figures, for this period and the one before ─────────────────────────────────────
  const figures = (r: PeriodRange, running: boolean) => {
    // Only a still-running period has a partial day to leave out of its averages.
    const avg = (map: Map<string, number>) => mean(valuesIn(map, r, today, { excludeToday: running }));
    return {
      calories: avg(daily.calories),
      steps: avg(daily.steps),
      weightChange: weightChange(daily.weight, r),
      workouts: sum(valuesIn(daily.workouts, r, today, { excludeToday: false })),
      volume: sum(valuesIn(daily.volume, r, today, { excludeToday: false })),
      cardioKm: sum(valuesIn(daily.cardioKm, r, today, { excludeToday: false })),
      // "Has anything been recorded at all?" — what decides whether a comparison has a counterpart.
      hasMeals: valuesIn(daily.calories, r, today, { excludeToday: false }).length > 0,
      hasSteps: valuesIn(daily.steps, r, today, { excludeToday: false }).length > 0,
    };
  };
  const cur = figures(range, isCurrent);
  const prev = figures(previousRange, false);

  // ── KPIs ─────────────────────────────────────────────────────────────────────────────────────
  const calorieGoal = goals.calories != null && goals.calories > 0 ? goals.calories : null;
  // Against the goal when there is one (the canvas' "−77 a célhoz"); otherwise against the previous average, in
  // neutral grey — without a goal nobody can say whether more or fewer kcal is better.
  let caloriesDelta: KpiDelta | null = null;
  if (cur.calories != null) {
    if (calorieGoal != null) {
      const amount = cur.calories - calorieGoal;
      caloriesDelta = { amount, percent: amount / calorieGoal, tone: calorieVerdict(cur.calories, calorieGoal) === "onTarget" ? "good" : "bad" };
    } else {
      const vsPrevious = compare(cur.calories, prev.calories, "lower", false);
      caloriesDelta = vsPrevious && { ...vsPrevious, tone: "neutral" };
    }
  }

  // Weight: the change over the period is the figure; it is an improvement when it moves toward the goal weight.
  const firstWeight = daysIn(range).map((d) => daily.weight.get(iso(d))).find((v) => v != null) ?? null;
  const weightDirection: "higher" | "lower" | null =
    goals.weightKg == null || firstWeight == null || goals.weightKg === firstWeight ? null : goals.weightKg < firstWeight ? "lower" : "higher";
  const weightDelta: KpiDelta | null =
    cur.weightChange == null
      ? null
      : {
          amount: cur.weightChange,
          percent: null,
          tone: weightDirection == null ? "neutral" : deltaTone(cur.weightChange, weightDirection),
        };

  const partial = isCurrent;
  const kpis: PeriodStats["kpis"] = {
    calories: { value: cur.calories, previous: prev.calories, delta: caloriesDelta, goal: calorieGoal },
    weight: { value: cur.weightChange, previous: prev.weightChange, delta: weightDelta },
    workouts: {
      value: cur.workouts,
      previous: prev.workouts > 0 ? prev.workouts : null,
      delta: compare(cur.workouts, prev.workouts > 0 ? prev.workouts : null, "higher", partial),
    },
    volume: {
      value: cur.volume,
      previous: prev.volume > 0 ? prev.volume : null,
      delta: compare(cur.volume, prev.volume > 0 ? prev.volume : null, "higher", partial),
    },
    cardio: {
      value: cur.cardioKm,
      previous: prev.cardioKm > 0 ? prev.cardioKm : null,
      delta: compare(cur.cardioKm, prev.cardioKm > 0 ? prev.cardioKm : null, "higher", partial),
    },
    // An average (today left out) is comparable with the previous average — no `partial` softening.
    steps: { value: cur.steps, previous: prev.steps, delta: compare(cur.steps, prev.steps, "higher", false) },
  };

  // ── chart series ─────────────────────────────────────────────────────────────────────────────
  const calorieValues = slots.map((s) => slotValue(daily.calories, s, today, weekly ? "mean" : "sum", weekly));
  const firstLog = daily.firstMeal;
  const emptySlotsBefore = weekly && firstLog ? slots.filter((s) => s.end.getTime() < firstLog.getTime()).length : 0;

  const weightValues = slots.map((s) => slotValue(daily.weight, s, today, "mean", false));
  const weightPoints = weightValues.filter((v): v is number => v != null);
  const scale = weightScale(weightPoints, goals.weightKg);

  const volumeValues = slots.map((s) => slotValue(daily.volume, s, today, "sum", false));
  const hadWorkout = slots.map((s) => valuesIn(daily.workouts, { start: s.start, end: s.end }, today, { excludeToday: false }).length > 0);
  // A finished slot with no workout is a rest day (a dot on the axis); today and the future are simply not drawn yet,
  // and neither is anything before the first thing the account ever recorded.
  const firstData = daily.firstData;
  const rest = slots.map((s, i) => !s.isFuture && !s.isCurrent && !hadWorkout[i] && firstData != null && s.end.getTime() >= firstData.getTime());

  const cardioValues = slots.map((s) => {
    const v = slotValue(daily.cardioKm, s, today, "sum", false);
    return v == null ? null : Math.round(v * 100) / 100;
  });
  const cardioSessions = distanceSessionsIn(raw, range);

  const stepValues = slots.map((s) => slotValue(daily.steps, s, today, "mean", weekly));

  return {
    period,
    range,
    previousRange,
    isCurrent,
    slots,
    kpis,
    calories: {
      values: calorieValues,
      average: cur.calories,
      loggedDays: valuesIn(daily.calories, range, today, { excludeToday: isCurrent }).length,
      goal: calorieGoal,
      firstLog,
      emptySlotsBefore,
      previousEmpty: !prev.hasMeals,
    },
    weight: {
      values: weightValues,
      latest: weightPoints.length ? weightPoints[weightPoints.length - 1] : null,
      goal: goals.weightKg,
      goalOutsideScale: scale != null && goals.weightKg != null && (goals.weightKg < scale.min || goals.weightKg > scale.max),
      scale,
    },
    volume: { values: volumeValues, rest, total: cur.volume },
    cardio: { values: cardioValues, totalKm: Math.round(cur.cardioKm * 100) / 100, sessions: cardioSessions },
    steps: { values: stepValues, average: cur.steps, goal: goals.steps },
  };
}

/**
 * The weight chart's Y range: the measurements, padded a little — and widened to the goal only when the goal is
 * close. A 65 kg goal under a week of 69–70 kg would squash the line into the top sliver, so then the goal stays
 * off-scale (and the card says so).
 */
export function weightScale(points: number[], goal: number | null): { min: number; max: number } | null {
  if (points.length === 0) return null;
  const lo = Math.min(...points);
  const hi = Math.max(...points);
  const pad = Math.max((hi - lo) * 0.15, 0.3);
  let min = lo - pad;
  let max = hi + pad;
  if (goal != null) {
    const widenedMin = Math.min(min, goal - pad);
    const widenedMax = Math.max(max, goal + pad);
    if (widenedMax - widenedMin <= (max - min) * 1.4) {
      min = widenedMin;
      max = widenedMax;
    }
  }
  // Whole and half kilos at both ends, and a span of whole kilos so the middle tick is a clean .0 or .5 too.
  const bottom = Math.floor(min * 2) / 2;
  let top = Math.ceil(max * 2) / 2;
  if (((top - bottom) * 2) % 2 !== 0) top += 0.5;
  return { min: bottom, max: top };
}

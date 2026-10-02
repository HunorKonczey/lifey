import type { DailyStepCountResponse } from "./types";

export interface StepDay {
  date: Date;
  steps: number;
  isToday: boolean;
  /** At or above the goal — for today too, but today never counts in the tallies (still accumulating). */
  met: boolean;
}

export interface StepsWindow {
  /** Oldest first, the last one is `end`. */
  days: StepDay[];
  /** Mean steps of the complete days that have a count (today left out); null when there is none. */
  average: number | null;
  /** Complete days that reached the goal. */
  metDays: number;
  /** Complete days in the window: 13 of 14 when today is in it. */
  completeDays: number;
  /** The biggest day of the whole window, today included; null when nothing was counted. */
  best: { date: Date; steps: number } | null;
}

const day = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
const addDays = (d: Date, n: number) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
const iso = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

/**
 * The "last 14 days" of the steps page (W4.6, W4-C): one day per column ending at `end`, each with its count and
 * whether it reached `goal`. The average and "cél teljesítve 6 / 13 nap" leave today out — a half-walked day would drag
 * the average down and count as a miss — and the average skips days with no count at all (nothing recorded is not a
 * day of zero steps). The best day looks at the whole window, today included.
 */
export function stepsWindow(entries: readonly DailyStepCountResponse[], goal: number, end: Date, now: Date, days = 14): StepsWindow {
  const byDate = new Map(entries.map((e) => [e.date, e.steps]));
  const today = day(now);
  const last = day(end);
  const window: StepDay[] = Array.from({ length: days }, (_, i) => {
    const date = addDays(last, -(days - 1 - i));
    const steps = byDate.get(iso(date)) ?? 0;
    return { date, steps, isToday: date.getTime() === today.getTime(), met: goal > 0 && steps >= goal };
  });

  const complete = window.filter((d) => d.date.getTime() < today.getTime());
  const counted = complete.filter((d) => d.steps > 0);
  const top = window.reduce<StepDay | null>((best, d) => (d.steps > 0 && (best == null || d.steps > best.steps) ? d : best), null);

  return {
    days: window,
    average: counted.length === 0 ? null : counted.reduce((s, d) => s + d.steps, 0) / counted.length,
    metDays: complete.filter((d) => d.met).length,
    completeDays: complete.length,
    best: top ? { date: top.date, steps: top.steps } : null,
  };
}

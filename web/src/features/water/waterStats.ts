import type { WaterEntryResponse } from "./types";

export interface WaterDay {
  date: Date;
  liters: number;
  isToday: boolean;
  /** At or above the goal — for today too, but today never counts in the stats (still filling). */
  met: boolean;
}

export interface WaterWindow {
  /** Oldest first, the last one is `end`. */
  days: WaterDay[];
  /** Mean litres of the complete days (today left out); null when there is none. */
  average: number | null;
  /** Complete days that reached the goal. */
  metDays: number;
  /** Complete days in the window: 13 of 14 when today is in it. */
  completeDays: number;
}

const day = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
const addDays = (d: Date, n: number) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
const key = (d: Date) => `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;

/** Litres per local calendar day. */
export function litersByDay(entries: readonly WaterEntryResponse[]): Map<string, number> {
  const totals = new Map<string, number>();
  for (const e of entries) {
    const k = key(new Date(e.consumedAt));
    totals.set(k, (totals.get(k) ?? 0) + e.volumeLiters);
  }
  return totals;
}

/**
 * The "last 14 days" of the water page (W4.5): one day per column ending at `end`, each with its litres and whether
 * it reached `goal`; the average and the "goal met 6 / 13 days" line leave today out — a half-drunk day would drag
 * the average down and count as a miss. Sums are rounded to the millilitre so 0,1 + 0,2 never misses a 0,3 goal.
 */
export function waterWindow(entries: readonly WaterEntryResponse[], goal: number, end: Date, now: Date, days = 14): WaterWindow {
  const totals = litersByDay(entries);
  const today = day(now);
  const last = day(end);
  const window: WaterDay[] = Array.from({ length: days }, (_, i) => {
    const date = addDays(last, -(days - 1 - i));
    const liters = Math.round((totals.get(key(date)) ?? 0) * 1000) / 1000;
    return { date, liters, isToday: date.getTime() === today.getTime(), met: goal > 0 && liters >= goal };
  });
  const complete = window.filter((d) => !d.isToday && d.date.getTime() < today.getTime());
  const logged = complete.filter((d) => d.liters > 0);
  return {
    days: window,
    average: logged.length === 0 ? null : logged.reduce((s, d) => s + d.liters, 0) / logged.length,
    metDays: complete.filter((d) => d.met).length,
    completeDays: complete.length,
  };
}

/** "kb. 4 pohár": what is left to drink in units of the usual container (the most used source's volume, else 0,25 L). Never 0 while something is left. */
export function containersLeft(remainingLiters: number, containerLiters: number): number {
  if (remainingLiters <= 0) return 0;
  const size = containerLiters > 0 ? containerLiters : 0.25;
  return Math.max(1, Math.round(remainingLiters / size));
}

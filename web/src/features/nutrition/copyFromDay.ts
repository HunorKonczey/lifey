import type { MealResponse } from "./types";

const DAY_MS = 24 * 60 * 60 * 1000;

function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function sameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

/** `days` calendar days before `date` (DST-proof: steps the date field, not milliseconds). */
export function daysBefore(date: Date, days: number): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() - days);
}

/** The two quick chips of the copy-from-day popover: the day before the one being viewed and the one before that. */
export function quickSourceDays(target: Date): [Date, Date] {
  return [daysBefore(target, 1), daysBefore(target, 2)];
}

/** The meals logged on `day`, in the order they happened. */
export function mealsOnDay(meals: MealResponse[], day: Date): MealResponse[] {
  return meals
    .filter((m) => sameDay(new Date(m.dateTime), day))
    .sort((a, b) => new Date(a.dateTime).getTime() - new Date(b.dateTime).getTime());
}

/** A local calendar day as a map key (`YYYY-M-D`, month zero-based). */
export function dayKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

/** Keys of every day that has a logged meal — for the calendar's data dots. */
export function loggedDayKeys(meals: MealResponse[]): Set<string> {
  return new Set(meals.map((m) => dayKey(new Date(m.dateTime))));
}

/** Whole calendar days from `from` to `to` (positive when `to` is later). */
export function calendarDaysBetween(from: Date, to: Date): number {
  return Math.round((startOfDay(to).getTime() - startOfDay(from).getTime()) / DAY_MS);
}

/** Which of the popover's day chips a source day corresponds to; anything else is "another day". */
export type SourceChip = "first" | "second" | "other";

export function sourceChip(source: Date, target: Date): SourceChip {
  const back = calendarDaysBetween(source, target);
  if (back === 1) return "first";
  if (back === 2) return "second";
  return "other";
}

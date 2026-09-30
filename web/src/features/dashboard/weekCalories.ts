import { averageExcludingPartialToday } from "@/components/ds/charts/chartMath";
import type { MealResponse } from "@/features/nutrition/types";

/** One bar of the dashboard's 7-day calories chart. */
export interface WeekDay {
  date: Date;
  kcal: number;
  /** The real, still-accumulating day — drawn dashed and kept out of every statistic. */
  isToday: boolean;
}

function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function dayKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

/**
 * The seven calendar days ending on `endDate` (the day the dashboard is
 * showing), oldest first, each with the calories logged on it. Only the real
 * today counts as partial: looking at a past day, all seven are complete.
 */
export function weekDays(meals: Pick<MealResponse, "dateTime" | "entries">[], endDate: Date, now: Date): WeekDay[] {
  const kcalByDay = new Map<string, number>();
  for (const m of meals) {
    const key = dayKey(new Date(m.dateTime));
    kcalByDay.set(key, (kcalByDay.get(key) ?? 0) + m.entries.reduce((sum, e) => sum + e.calories, 0));
  }

  const end = startOfDay(endDate);
  const today = startOfDay(now);
  return Array.from({ length: 7 }, (_, i) => {
    const date = new Date(end.getFullYear(), end.getMonth(), end.getDate() - (6 - i));
    return { date, kcal: kcalByDay.get(dayKey(date)) ?? 0, isToday: date.getTime() === today.getTime() };
  });
}

export interface WeekStats {
  /** Mean kcal over the complete days that have anything logged; null if there are none. */
  averageKcal: number | null;
  /** Complete days with 0 < kcal ≤ goal; null without a goal. */
  withinGoal: number | null;
  /** The complete days (today excluded) — the "6" in "5 / 6". */
  completeDays: number;
  /** Sessions started inside the window. */
  workouts: number;
}

/**
 * The header numbers of the week card. Today is excluded from all of them —
 * a half-logged day would drag the average down and can't be "within goal"
 * yet — and a day with nothing logged (0 kcal means "didn't log", not "ate
 * nothing") is neither averaged nor counted as within goal, though it still
 * counts in the "of N".
 */
export function weekStats(
  days: WeekDay[],
  goalKcal: number | null,
  sessionStartTimes: string[],
  now: Date,
): WeekStats {
  const complete = days.filter((d) => !d.isToday);
  const averageKcal = averageExcludingPartialToday(
    days.map((d) => ({ day: d.date, value: d.kcal })),
    now,
    { ignoreZero: true },
  );

  const hasGoal = goalKcal != null && goalKcal > 0;
  const withinGoal = hasGoal ? complete.filter((d) => d.kcal > 0 && d.kcal <= goalKcal).length : null;

  const first = days[0].date.getTime();
  const lastExclusive = new Date(days[6].date.getFullYear(), days[6].date.getMonth(), days[6].date.getDate() + 1).getTime();
  const workouts = sessionStartTimes.filter((t) => {
    const at = new Date(t).getTime();
    return at >= first && at < lastExclusive;
  }).length;

  return { averageKcal, withinGoal, completeDays: complete.length, workouts };
}

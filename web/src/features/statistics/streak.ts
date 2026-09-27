import { format, subDays } from "date-fns";

/**
 * Consecutive calendar days (local time) with at least one logged meal or
 * workout, counted back from `today`. Today not being logged *yet* doesn't
 * break the streak — it counts from yesterday then, the same forgiving rule
 * the mobile streaks use (docs/37-streaks-weekly-recap-plan.md).
 *
 * Replaces the dashboard's old "streak", which was just the length of the
 * five-item recent-workouts list and so could never exceed 5.
 */
export function loggingStreak(timestamps: Iterable<string>, today: Date = new Date()): number {
  const days = new Set<string>();
  for (const ts of timestamps) days.add(format(new Date(ts), "yyyy-MM-dd"));

  let cursor = today;
  if (!days.has(format(cursor, "yyyy-MM-dd"))) cursor = subDays(cursor, 1);

  let streak = 0;
  while (days.has(format(cursor, "yyyy-MM-dd"))) {
    streak += 1;
    cursor = subDays(cursor, 1);
  }
  return streak;
}

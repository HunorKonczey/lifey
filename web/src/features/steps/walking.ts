/** The step goal every surface uses when the user hasn't set one — the same
 *  default as mobile's `UserSettings.defaultDailyStepGoal`. */
export const DEFAULT_DAILY_STEP_GOAL = 10_000;

/** A brisk walk, for "about N minutes" — one constant, used everywhere. */
export const STEPS_PER_MINUTE = 100;

/** The goal in effect: the user's own when it's a positive number, else the default. One helper for
 *  the dashboard tile and the steps page (mobile: `effectiveDailyStepGoal`). */
export function effectiveDailyStepGoal(settings: { dailyStepGoal?: number | null } | null | undefined): number {
  const goal = settings?.dailyStepGoal;
  return goal != null && goal > 0 ? goal : DEFAULT_DAILY_STEP_GOAL;
}

/** How long walking `steps` takes, rounded to the nearest 5 minutes (never less than 5) —
 *  the "kb. 25 perc séta" beside "still 2 588 steps". */
export function walkingMinutes(steps: number): number {
  return Math.max(5, Math.round(steps / STEPS_PER_MINUTE / 5) * 5);
}

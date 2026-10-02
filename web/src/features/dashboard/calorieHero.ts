/** What the calorie hero shows for one day (W1.2) — the three states of the
 *  canvas, as a pure function so the copy/number choice is unit-tested
 *  without rendering. */
export type HeroMode = "remaining" | "over" | "noGoal";

export interface HeroState {
  mode: HeroMode;
  /** Ring progress: eaten / goal (past 1 the ring draws its second lap). 0 without a goal. */
  ringProgress: number;
  /** The big number: kcal left, the overage, or — without a goal — what was eaten. */
  number: number;
  /** Message key under `dashboard` for the caption beside the number. */
  captionKey: "kcalLeft" | "kcalOver" | "kcalEaten";
  /** The "Daily goal" line only exists when a goal does. */
  showGoalLine: boolean;
}

export function heroState(eaten: number, goal: number | null | undefined): HeroState {
  const hasGoal = goal != null && goal > 0;
  if (!hasGoal) {
    return { mode: "noGoal", ringProgress: 0, number: Math.round(eaten), captionKey: "kcalEaten", showGoalLine: false };
  }
  if (eaten > goal) {
    return { mode: "over", ringProgress: eaten / goal, number: Math.round(eaten - goal), captionKey: "kcalOver", showGoalLine: true };
  }
  return { mode: "remaining", ringProgress: eaten / goal, number: Math.round(goal - eaten), captionKey: "kcalLeft", showGoalLine: true };
}

/** One macro row of the hero: a bar and "left/over" text only when it has a goal. */
export interface MacroRowState {
  hasGoal: boolean;
  progress: number;
  /** Grams still to go; 0 once reached. */
  left: number;
  /** Grams past the goal; 0 until exceeded. */
  over: number;
}

export function macroRowState(value: number, goal: number | null | undefined): MacroRowState {
  if (goal == null || goal <= 0) return { hasGoal: false, progress: 0, left: 0, over: 0 };
  return {
    hasGoal: true,
    progress: value / goal,
    left: Math.max(0, Math.round(goal - value)),
    over: Math.max(0, Math.round(value - goal)),
  };
}

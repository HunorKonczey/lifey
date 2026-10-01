/** The three things a new account does first (W1.11, W1-D). Each completes on
 *  its own — weight can come before the first meal. */
export type FirstStepId = "goals" | "meal" | "weight";

export interface FirstStepsInput {
  /** A calorie goal exists (set in onboarding or settings). */
  hasGoal: boolean;
  hasMeal: boolean;
  hasWeight: boolean;
}

export interface FirstStepsState {
  steps: { id: FirstStepId; done: boolean }[];
  /** No meal ever and no weight ever — the account that gets this card *instead of* the zeroed hero and tiles. */
  fresh: boolean;
  /** A meal and a weight both exist — nothing left to prompt. Goals aren't required: they're a setting, not a log. */
  complete: boolean;
}

export function firstStepsState({ hasGoal, hasMeal, hasWeight }: FirstStepsInput): FirstStepsState {
  return {
    steps: [
      { id: "goals", done: hasGoal },
      { id: "meal", done: hasMeal },
      { id: "weight", done: hasWeight },
    ],
    fresh: !hasMeal && !hasWeight,
    complete: hasMeal && hasWeight,
  };
}

/**
 * Whether the dashboard shows the card in place of hero + tiles. A fresh
 * account shows it; once shown it **stays** while the user works through it —
 * logging the first meal must tick step 2 on screen rather than make the
 * whole card vanish and the zeroed hero jump back — until both a meal and a
 * weight exist, or the user dismisses it.
 */
export function showFirstSteps(state: FirstStepsState, { pinned, dismissed }: { pinned: boolean; dismissed: boolean }): boolean {
  if (dismissed || state.complete) return false;
  return state.fresh || pinned;
}

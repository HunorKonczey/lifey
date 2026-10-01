import type { SuggestGoalsResponse } from "./types";

/** Within this many kcal of the maintenance calories counts as "around what you burn". */
const MAINTAIN_BAND_KCAL = 25;

export type PlanKind = "deficit" | "maintain" | "surplus";

export interface PlanSentence {
  kind: PlanKind;
  /** Absolute kcal gap between the suggested calories and the maintenance calories (TDEE). */
  gap: number;
}

/**
 * What the suggested-plan hero says, as data (the words live in the message files): is the suggested intake below,
 * around or above what the person burns, and by how much. It follows the numbers the backend returned, not the goal
 * the person picked — a "lose weight" plan clamped up to maintenance reads as maintenance.
 */
export function planSentence(plan: Pick<SuggestGoalsResponse, "calories" | "tdee">): PlanSentence {
  const diff = plan.calories - plan.tdee;
  const gap = Math.abs(Math.round(diff));
  if (gap <= MAINTAIN_BAND_KCAL) return { kind: "maintain", gap };
  return { kind: diff < 0 ? "deficit" : "surplus", gap };
}

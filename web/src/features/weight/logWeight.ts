import type { WeightRequest, WeightResponse } from "./types";

export const MIN_WEIGHT_KG = 20;
export const MAX_WEIGHT_KG = 500;
export const WEIGHT_STEP_KG = 0.1;
export const WEIGHT_BIG_STEP_KG = 1;

/** Round to the 0,1 kg the scale shows and keep it inside what a person can weigh. */
export function clampWeight(kg: number): number {
  return Math.min(MAX_WEIGHT_KG, Math.max(MIN_WEIGHT_KG, Math.round(kg * 10) / 10));
}

/** ↑/↓ step the value by 0,1 kg, Shift by 1 kg — the drawer's keyboard contract. */
export function stepWeight(kg: number, direction: 1 | -1, shift: boolean): number {
  return clampWeight(kg + direction * (shift ? WEIGHT_BIG_STEP_KG : WEIGHT_STEP_KG));
}

/** What the drawer opens with: the entry being edited, else the last weigh-in (so a typical day is one tick away), else 70. */
export function initialWeight(weights: readonly WeightResponse[], editing: WeightResponse | null): number {
  if (editing) return editing.weight;
  const last = [...weights].sort((a, b) => a.date.localeCompare(b.date) || a.id - b.id).at(-1);
  return last?.weight ?? 70;
}

export interface WeightSavePlan {
  /** The entry to create — always first, so a failure never leaves the day empty. */
  create: WeightRequest;
  /** Entries to remove once it exists: the edited one and any others already on that date. */
  deleteIds: number[];
  /** Other entries on the date (not the one being edited) — replacing them asks first. */
  conflicts: WeightResponse[];
}

/**
 * How saving the drawer maps onto an API that has only create and delete (W4.4): a new weigh-in is a create; an edit is
 * a create followed by deleting the old entry ("delete + create with the same date, as one action"); and since the
 * backend allows several entries a day, anything already on the chosen date is replaced — after a confirm, which the
 * caller shows when `conflicts` is not empty.
 */
export function planWeightSave(weights: readonly WeightResponse[], editing: WeightResponse | null, date: string, weight: number): WeightSavePlan {
  const conflicts = weights.filter((w) => w.date === date && w.id !== editing?.id);
  const deleteIds = [...(editing ? [editing.id] : []), ...conflicts.map((c) => c.id)];
  return { create: { date, weight: clampWeight(weight) }, deleteIds, conflicts };
}

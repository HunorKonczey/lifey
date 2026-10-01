/** Atwater factors the nutrition label is built on: kcal per gram of protein, carbs and fat. */
const KCAL_PER_GRAM = { protein: 4, carbs: 4, fat: 9 } as const;

/** A warning (rather than a plain note) once the macros are off by more than this share of the stated kcal. */
export const MACRO_WARNING_SHARE = 0.1;

export interface MacroInput {
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
}

export interface MacroCheck {
  /** What 4·P + 4·C + 9·F comes to, rounded to a whole kcal. */
  computedKcal: number;
  /** How far that is from the stated kcal (whole kcal, never negative). */
  diffKcal: number;
  /** `ok` — they agree, nothing is shown; `info` — a small mismatch; `warning` — more than 10 % off. */
  tone: "ok" | "info" | "warning";
}

/**
 * Does the food's own kcal match its macros? Real labels rarely add up to the
 * digit (fibre, alcohol, rounding), so any difference is an info line and only a
 * large one is a warning — the food is saved either way; this only points it out.
 */
export function macroCheck({ kcal, protein, carbs, fat }: MacroInput): MacroCheck {
  const computedKcal = Math.round(
    protein * KCAL_PER_GRAM.protein + carbs * KCAL_PER_GRAM.carbs + fat * KCAL_PER_GRAM.fat,
  );
  const stated = Math.round(kcal);
  const diffKcal = Math.abs(computedKcal - stated);
  if (diffKcal === 0) return { computedKcal, diffKcal, tone: "ok" };
  // No stated kcal to take a share of: any macros at all are then the whole discrepancy.
  const share = stated > 0 ? diffKcal / stated : Infinity;
  return { computedKcal, diffKcal, tone: share > MACRO_WARNING_SHARE ? "warning" : "info" };
}

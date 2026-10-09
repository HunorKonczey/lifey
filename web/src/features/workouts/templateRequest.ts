import type { TemplateExerciseEntry, WorkoutTemplateRequest, WorkoutTemplateResponse } from "./types";

/** Longest workout a template may state, in minutes - the backend's own cap. */
export const MAX_TEMPLATE_MINUTES = 1000;

/** The repetition count cap the backend enforces. */
export const MAX_TEMPLATE_REPS = 1000;

/**
 * What a count field holds after the author typed into it: digits only, nothing or zero is "not said" (null), and a
 * number above `max` is held at `max` - so the field can never be in a state the backend would refuse.
 */
export function sanitizeCount(value: string, max: number): number | null {
  const digits = value.replace(/\D/g, "");
  if (digits === "") return null;
  const n = parseInt(digits, 10);
  return n <= 0 ? null : Math.min(n, max);
}

/**
 * The request a save sends (LIF-106). The backend reads an absent duration or repetition count as "keep what is stored"
 * (the phone, which does not know them, sends none) and 0 as "clear it", so a field the author emptied has to say 0
 * explicitly - while one that was never set is simply left out.
 */
export function buildTemplateRequest(
  saved: Pick<WorkoutTemplateResponse, "durationMinutes" | "exercises"> | null,
  name: string,
  rows: readonly TemplateExerciseEntry[],
  durationMinutes: number | null,
): WorkoutTemplateRequest {
  const savedReps = new Map(saved?.exercises.map((e) => [e.exerciseId, e.targetReps]) ?? []);
  return {
    name: name.trim(),
    exercises: rows.map((row) => {
      const entry: TemplateExerciseEntry = { exerciseId: row.exerciseId, targetSets: row.targetSets };
      if (row.targetReps != null && row.targetReps > 0) entry.targetReps = row.targetReps;
      else if (savedReps.get(row.exerciseId)) entry.targetReps = 0;
      return entry;
    }),
    ...(durationMinutes != null ? { durationMinutes } : saved?.durationMinutes ? { durationMinutes: 0 } : {}),
  };
}

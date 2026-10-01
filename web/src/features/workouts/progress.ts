import type { WorkoutSessionResponse, ExerciseSetResponse } from "./types";

/**
 * The most recent *other* session that logged sets for `exerciseId`,
 * preferring one started from the same `templateId` if given. Falls back to
 * the most recent session with this exercise regardless of template when the
 * template-scoped search comes up empty (or no template was given). Returns
 * that session's sets for this exercise sorted by weight descending, so
 * callers can pair them positionally with the current session's rows.
 */
export function previousSets(
  history: WorkoutSessionResponse[],
  currentId: number,
  exerciseId: number,
  templateId: number | null,
): ExerciseSetResponse[] {
  const others = history.filter((s) => s.id !== currentId);

  const lastSessionWithExercise = (candidates: WorkoutSessionResponse[]) =>
    candidates
      .filter((s) => s.sets.some((set) => set.exerciseId === exerciseId))
      .sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime())[0] ?? null;

  const session =
    (templateId != null ? lastSessionWithExercise(others.filter((s) => s.templateId === templateId)) : null) ??
    lastSessionWithExercise(others);
  if (!session) return [];

  return session.sets
    .filter((set) => set.exerciseId === exerciseId)
    .sort((a, b) => b.weight - a.weight);
}

/** "up" if `current` beat `previous`, "down" if it fell short, null if unchanged/incomparable. */
export function delta(current: number, previous: number | undefined): "up" | "down" | null {
  if (previous === undefined || current === previous) return null;
  return current > previous ? "up" : "down";
}

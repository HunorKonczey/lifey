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

export interface DraftSetLike {
  exerciseId: number;
  weight: number;
  reps: number;
  done: boolean;
}

export interface WorkoutImprovement {
  exerciseName: string;
  chips: string[];
}

export interface WorkoutProgressResult {
  /** Net count of green up-arrows minus red down-arrows across every done set's weight and reps. */
  score: number;
  improvements: WorkoutImprovement[];
}

/** Popup only shows when the user improved in at least 2 metrics net. */
export function isWorkoutSuccess(result: WorkoutProgressResult): boolean {
  return result.score >= 2;
}

/**
 * Computes the workout-success trigger score and per-exercise improvement
 * chips, comparing each done draft positionally against [previousSets] for
 * its exercise (mirrors the up/down arrow logic already shown per set).
 */
export function computeWorkoutProgress(
  session: WorkoutSessionResponse,
  drafts: DraftSetLike[],
  history: WorkoutSessionResponse[],
  exercises: { exerciseId: number; exerciseName: string }[],
  formatWeight: (n: number) => string,
  repsUnit: string,
  kgUnit: string,
): WorkoutProgressResult {
  let score = 0;
  const improvements: WorkoutImprovement[] = [];

  for (const ex of exercises) {
    const prevSets = previousSets(history, session.id, ex.exerciseId, session.templateId);
    const exDrafts = drafts.filter((d) => d.exerciseId === ex.exerciseId);

    let weightGain = 0;
    let repsGain = 0;
    exDrafts.forEach((d, localIdx) => {
      if (!d.done) return;
      const prev = prevSets[localIdx];
      if (!prev) return;

      const weightDelta = delta(d.weight, prev.weight);
      if (weightDelta === "up") { score++; weightGain += d.weight - prev.weight; }
      else if (weightDelta === "down") score--;

      const repsDelta = delta(d.reps, prev.reps);
      if (repsDelta === "up") { score++; repsGain += d.reps - prev.reps; }
      else if (repsDelta === "down") score--;
    });

    const chips: string[] = [];
    if (weightGain > 0) chips.push(`+${formatWeight(weightGain)} ${kgUnit}`);
    if (repsGain > 0) chips.push(`+${repsGain} ${repsUnit}`);
    if (chips.length > 0) improvements.push({ exerciseName: ex.exerciseName, chips });
  }

  return { score, improvements };
}

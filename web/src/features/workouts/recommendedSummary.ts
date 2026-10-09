import type { WorkoutSessionResponse, WorkoutTemplateResponse } from "./types";

export interface PreviewExercise {
  exerciseId: number;
  name: string;
  sets: number;
  /** Typical reps from the last time the exercise was logged — null if never. */
  reps: number | null;
}

export interface RecommendedSummary {
  exerciseCount: number;
  totalSets: number;
  /** The template's median past duration, else 8 minutes an exercise; rounded to 5. */
  estimatedMinutes: number;
  /** When the template was last finished, null if never. */
  lastPerformed: Date | null;
  /** The first three exercises, for the card's list. */
  preview: PreviewExercise[];
}

const FALLBACK_MINUTES_PER_EXERCISE = 8;
const PREVIEW_COUNT = 3;

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

function roundToFive(minutes: number): number {
  return Math.max(5, Math.round(minutes / 5) * 5);
}

/**
 * The numbers on the dashboard's recommended-workout card (W1.4), derived
 * from the template and the user's history (`sessionsDesc` is newest first).
 * Sessions that never finished, or whose recorded duration is zero (an
 * instantly-closed session), say nothing about how long the workout takes and
 * are ignored for the estimate.
 */
export function summarizeTemplate(
  template: WorkoutTemplateResponse,
  sessionsDesc: WorkoutSessionResponse[],
  exerciseNames: ReadonlyMap<number, string>,
): RecommendedSummary {
  const finished = sessionsDesc.filter((s) => s.templateId === template.id && s.finishedAt != null);

  const durations = finished
    .map((s) => (new Date(s.finishedAt!).getTime() - new Date(s.startedAt).getTime()) / 60_000)
    .filter((m) => m > 0);
  // The author's own duration (LIF-106) beats any estimate; otherwise the median of the finished runs, else a guess per exercise.
  const estimatedMinutes =
    template.durationMinutes && template.durationMinutes > 0
      ? template.durationMinutes
      : roundToFive(durations.length > 0 ? median(durations) : template.exercises.length * FALLBACK_MINUTES_PER_EXERCISE);

  const preview = template.exercises.slice(0, PREVIEW_COUNT).map((e) => {
    // Newest session that logged this exercise — its median reps is what "4 × 8" shows.
    const last = sessionsDesc.find((s) => s.sets.some((set) => set.exerciseId === e.exerciseId));
    const reps = last
      ? Math.round(median(last.sets.filter((set) => set.exerciseId === e.exerciseId).map((set) => set.reps)))
      : e.targetReps && e.targetReps > 0
        ? e.targetReps // never performed: what the template itself asks for (LIF-106)
        : null;
    return { exerciseId: e.exerciseId, name: exerciseNames.get(e.exerciseId) ?? "", sets: e.targetSets, reps };
  });

  return {
    exerciseCount: template.exercises.length,
    totalSets: template.exercises.reduce((sum, e) => sum + e.targetSets, 0),
    estimatedMinutes,
    lastPerformed: finished.length > 0 ? new Date(finished[0].startedAt) : null,
    preview,
  };
}

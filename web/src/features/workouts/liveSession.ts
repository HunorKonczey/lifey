import type { ExerciseSetResponse, ExerciseSummary } from "./types";

/** A set as the live logger holds it while editing. */
export interface DraftSet {
  exerciseId: number;
  weight: number;
  reps: number;
  done: boolean;
}

/**
 * Whole seconds on the workout clock (W3.6). Derived from the timestamps, never counted by an interval, so it
 * survives a reload and a throttled background tab; a finished session shows its own length and stops.
 */
export function elapsedSeconds(startedAt: string, finishedAt: string | null, nowMs: number): number {
  const end = finishedAt != null ? new Date(finishedAt).getTime() : nowMs;
  return Math.max(0, Math.floor((end - new Date(startedAt).getTime()) / 1000));
}

export type RailState = "done" | "current" | "next";

export interface RailExercise {
  exerciseId: number;
  exerciseName: string;
  doneSets: number;
  totalSets: number;
  state: RailState;
}

/** The exercise list on the left of the logger: a finished exercise (every set done), the current one, the rest. */
export function railExercises(exercises: readonly ExerciseSummary[], drafts: readonly DraftSet[], currentId: number | null): RailExercise[] {
  return exercises.map((e) => {
    const own = drafts.filter((d) => d.exerciseId === e.exerciseId);
    const doneSets = own.filter((d) => d.done).length;
    const finished = own.length > 0 && doneSets === own.length;
    return {
      exerciseId: e.exerciseId,
      exerciseName: e.exerciseName,
      doneSets,
      totalSets: own.length,
      state: e.exerciseId === currentId ? "current" : finished ? "done" : "next",
    };
  });
}

/** Where the logger opens: the first exercise that still has work, else the first one. */
export function firstOpenExerciseId(exercises: readonly ExerciseSummary[], drafts: readonly DraftSet[]): number | null {
  const open = exercises.find((e) => {
    const own = drafts.filter((d) => d.exerciseId === e.exerciseId);
    return own.length === 0 || own.some((d) => !d.done);
  });
  return (open ?? exercises[0])?.exerciseId ?? null;
}

export interface LiveProgress {
  doneSets: number;
  /** The template's planned sets, or what has been logged when that is more (or there is no template). */
  totalSets: number;
  doneExercises: number;
  totalExercises: number;
}

/** "9 / 18 szett · 2 / 6 gyakorlat" — `plannedSets` is the template's Σ target sets (0 without a template). */
export function liveProgress(exercises: readonly ExerciseSummary[], drafts: readonly DraftSet[], plannedSets: number): LiveProgress {
  const doneSets = drafts.filter((d) => d.done).length;
  const rail = railExercises(exercises, drafts, null);
  return {
    doneSets,
    totalSets: Math.max(plannedSets, drafts.length),
    doneExercises: rail.filter((r) => r.state === "done").length,
    totalExercises: exercises.length,
  };
}

const signature = (sets: readonly Pick<ExerciseSetResponse, "exerciseId" | "weight" | "reps">[]) =>
  sets
    .map((s) => `${s.exerciseId}:${s.weight}:${s.reps}`)
    .sort()
    .join("|");

/** True when the drafts differ from what the server has saved — leaving then asks first. */
export function hasUnsavedSets(saved: readonly ExerciseSetResponse[], drafts: readonly DraftSet[]): boolean {
  return signature(saved) !== signature(drafts.filter((d) => d.done && d.reps > 0));
}

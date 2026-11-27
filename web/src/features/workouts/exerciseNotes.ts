import type { ExerciseSummary, PlannedExerciseRequest, WorkoutSessionResponse } from "./types";

/** The server's `PlannedExerciseRequest.MAX_NOTE_LENGTH` and mobile's `kExerciseNoteMaxLength` (LIF-224). */
export const EXERCISE_NOTE_MAX_LENGTH = 1000;

/** Trimmed, and blank → no comment — the same normalising the server and the mobile client do. */
export function normalizeExerciseNote(note: string | null | undefined): string | null {
  const trimmed = note?.trim() ?? "";
  return trimmed === "" ? null : trimmed;
}

/**
 * The comment the exercise had in its latest other started session that planned it — null when that session had
 * none (LIF-226). The same rule as the server's carry-over and mobile's `getPreviousExerciseNotes`, so "From last
 * session" means the same thing on every client.
 */
export function previousExerciseNote(
  history: readonly WorkoutSessionResponse[],
  sessionId: number,
  exerciseId: number,
): string | null {
  let latest: { startedAt: number; id: number; note: string | null } | null = null;
  for (const s of history) {
    if (s.id === sessionId || !s.startedAt) continue;
    const link = s.exercises.find((e) => e.exerciseId === exerciseId);
    if (!link) continue;
    const startedAt = new Date(s.startedAt).getTime();
    if (
      latest == null ||
      startedAt > latest.startedAt ||
      (startedAt === latest.startedAt && s.id > latest.id)
    ) {
      latest = { startedAt, id: s.id, note: normalizeExerciseNote(link.note) };
    }
  }
  return latest?.note ?? null;
}

/**
 * The session's plan as `plannedExercises` (LIF-226): when the web sends it, the server takes it as is, so every
 * exercise keeps its `targetSets` (planned on mobile or from the template) and its comment — the edited one from
 * `edits`, else the one the session already has.
 */
export function plannedExercisesRequest(
  exercises: readonly ExerciseSummary[],
  edits: ReadonlyMap<number, string | null>,
): PlannedExerciseRequest[] {
  return exercises.map((e) => ({
    exerciseId: e.exerciseId,
    targetSets: e.targetSets ?? null,
    note: edits.has(e.exerciseId)
      ? normalizeExerciseNote(edits.get(e.exerciseId))
      : normalizeExerciseNote(e.note),
  }));
}

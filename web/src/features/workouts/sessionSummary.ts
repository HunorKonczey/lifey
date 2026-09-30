import { baselineFromSets, detectPrs, estimateOneRepMax, extendBaseline, type PrBaseline, type PrType } from "./personalRecords";
import { previousSets } from "./progress";
import { effectiveSeconds, sessionVolumeKg } from "./sessionGroups";
import type { ExerciseSetResponse, WorkoutSessionResponse } from "./types";

/** A logged set reduced to what the summary shows. */
export interface SetLine {
  weight: number;
  reps: number;
}

export interface ExerciseSummaryLine {
  exerciseId: number;
  exerciseName: string;
  /** The exercise's sets in the order they were logged. */
  sets: SetLine[];
  /** Heaviest set (ties: more reps). */
  best: SetLine;
  /** True when `best` beat the best set of the previous session with this exercise — the "↑". */
  improved: boolean;
}

export interface SessionRecord {
  exerciseId: number;
  exerciseName: string;
  /** The record-breaking set. */
  set: SetLine;
  kinds: PrType[];
  /** The best set before this session, when there was one — "eddig 47,5 kg × 8". */
  previous: SetLine | null;
}

export interface SessionSummaryData {
  seconds: number | null;
  volumeKg: number;
  exercises: ExerciseSummaryLine[];
  /** One per exercise that set a record, best first (heaviest max-weight record, then the rest). */
  records: SessionRecord[];
}

const byPerformedAt = (a: ExerciseSetResponse, b: ExerciseSetResponse) =>
  new Date(a.performedAt).getTime() - new Date(b.performedAt).getTime();

function heavier(a: SetLine, b: SetLine): boolean {
  return a.weight > b.weight || (a.weight === b.weight && a.reps > b.reps);
}

function bestOf(sets: SetLine[]): SetLine {
  return sets.reduce((best, s) => (heavier(s, best) ? s : best));
}

/** Sets of finished strength sessions that started before `session` — the history its records are judged against. */
function priorSets(session: WorkoutSessionResponse, history: readonly WorkoutSessionResponse[]): ExerciseSetResponse[] {
  const started = new Date(session.startedAt).getTime();
  return history
    .filter((h) => h.id !== session.id && h.sessionKind === "STRENGTH" && h.finishedAt != null && new Date(h.startedAt).getTime() < started)
    .flatMap((h) => h.sets);
}

/** Everything the closed-session summary panel shows (W3.4). `history` may include the session itself. */
export function summarizeSession(session: WorkoutSessionResponse, history: readonly WorkoutSessionResponse[]): SessionSummaryData {
  const before = priorSets(session, history);
  const exercises: ExerciseSummaryLine[] = [];
  const records: SessionRecord[] = [];

  const ids = [...new Set([...session.exercises.map((e) => e.exerciseId), ...session.sets.map((s) => s.exerciseId)])];
  for (const exerciseId of ids) {
    const sets = session.sets.filter((s) => s.exerciseId === exerciseId).sort(byPerformedAt);
    if (sets.length === 0) continue;
    const exerciseName = sets[0].exerciseName ?? session.exercises.find((e) => e.exerciseId === exerciseId)?.exerciseName ?? "";
    const lines = sets.map((s) => ({ weight: s.weight, reps: s.reps }));
    const best = bestOf(lines);

    const prev = previousSets(history as WorkoutSessionResponse[], session.id, exerciseId, session.templateId)[0];
    exercises.push({ exerciseId, exerciseName, sets: lines, best, improved: prev != null && heavier(best, { weight: prev.weight, reps: prev.reps }) });

    // Records: replay this exercise's sets against everything logged before the session.
    const priorForExercise = before.filter((s) => s.exerciseId === exerciseId);
    let baseline: PrBaseline = baselineFromSets(priorForExercise);
    let recordSet: SetLine | null = null;
    const kinds = new Set<PrType>();
    for (const set of lines) {
      const found = detectPrs(baseline, set);
      if (found.length > 0) {
        found.forEach((k) => kinds.add(k));
        if (recordSet == null || heavier(set, recordSet)) recordSet = set;
      }
      baseline = extendBaseline(baseline, set);
    }
    if (recordSet) {
      const previous =
        priorForExercise.length === 0
          ? null
          : priorForExercise.reduce((top, s) => (estimateOneRepMax(s.weight, s.reps) > estimateOneRepMax(top.weight, top.reps) ? s : top));
      records.push({
        exerciseId,
        exerciseName,
        set: recordSet,
        kinds: [...kinds],
        previous: previous ? { weight: previous.weight, reps: previous.reps } : null,
      });
    }
  }

  records.sort((a, b) => b.set.weight - a.set.weight || b.set.reps - a.set.reps);
  return { seconds: effectiveSeconds(session), volumeKg: sessionVolumeKg(session), exercises, records };
}

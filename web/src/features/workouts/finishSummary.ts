import type { DraftSet } from "./liveSession";
import { summarizeSession, type SessionRecord } from "./sessionSummary";
import { weekStartFor } from "./sessionGroups";
import type { WorkoutSessionResponse } from "./types";

export interface CelebrationData {
  /** Wall-clock length of the workout. */
  seconds: number;
  volumeKg: number;
  /** Sets that were ticked and logged. */
  sets: number;
  /** One per exercise that set a record, heaviest first — the same list the summary panel shows. */
  records: SessionRecord[];
  /** "This was your Nth workout this week" — the workout itself included. */
  weekCount: number;
}

/**
 * What the celebration modal (W3.9) shows, computed from the drafts that were just saved — so it agrees with the
 * summary panel that opens afterwards (both go through `summarizeSession`). `history` is every session the
 * client knows; the workout being finished is counted once whether or not it is in there yet.
 */
export function celebrationData(
  session: WorkoutSessionResponse,
  drafts: readonly DraftSet[],
  history: readonly WorkoutSessionResponse[],
  finishedAt: Date,
): CelebrationData {
  const logged = drafts.filter((d) => d.done && d.reps > 0);
  const finished: WorkoutSessionResponse = {
    ...session,
    finishedAt: finishedAt.toISOString(),
    sets: logged.map((d) => ({
      exerciseId: d.exerciseId,
      exerciseName: session.exercises.find((e) => e.exerciseId === d.exerciseId)?.exerciseName ?? "",
      weight: d.weight,
      reps: d.reps,
      performedAt: finishedAt.toISOString(),
    })),
  };
  const summary = summarizeSession(finished, history);

  const weekStart = weekStartFor(new Date(session.startedAt)).getTime();
  const weekEnd = weekStart + 7 * 86_400_000 + 3_600_000; // +1 h: a DST week is 167 or 169 hours long
  const inWeek = history.filter((h) => h.id !== session.id && new Date(h.startedAt).getTime() >= weekStart && new Date(h.startedAt).getTime() < weekEnd);

  return {
    seconds: Math.max(0, Math.round((finishedAt.getTime() - new Date(session.startedAt).getTime()) / 1000)),
    volumeKg: summary.volumeKg,
    sets: logged.length,
    records: summary.records,
    weekCount: inWeek.length + 1,
  };
}

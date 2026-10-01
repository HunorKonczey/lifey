import { addDays, format } from "date-fns";
import { DAYS_OF_WEEK, type ProgramWorkoutRequest, type TrainerCalendarSessionResponse } from "./types";

/** Two timed workouts closer than this (minutes) on the same day clash. */
export const CONFLICT_WINDOW_MINUTES = 60;

export interface ProgramOccurrence {
  /** yyyy-MM-dd */
  date: string;
  /** "HH:mm" or null. */
  time: string | null;
  templateId: number;
}

/**
 * The calendar dates a program would put workouts on if it started on `startDate` (a Monday): week 1 starts that day, a
 * workout's day of week picks the column. Sorted by date, then time. This is the same arithmetic the backend does, so
 * the count and the span shown before assigning match what `occurrenceCount` then reports.
 */
export function programOccurrences(workouts: ProgramWorkoutRequest[], startDate: string): ProgramOccurrence[] {
  const start = new Date(`${startDate}T00:00:00`);
  return workouts
    .map((w) => ({
      date: format(addDays(start, (w.weekNumber - 1) * 7 + DAYS_OF_WEEK.indexOf(w.dayOfWeek)), "yyyy-MM-dd"),
      time: w.timeOfDay ? w.timeOfDay.slice(0, 5) : null,
      templateId: w.templateId,
    }))
    .sort((a, b) => a.date.localeCompare(b.date) || (a.time ?? "").localeCompare(b.time ?? ""));
}

/** How many workouts, and between which first and last day. Null for a program with none. */
export function consequenceSummary(occurrences: ProgramOccurrence[]): { count: number; firstDate: string; lastDate: string } | null {
  if (occurrences.length === 0) return null;
  return { count: occurrences.length, firstDate: occurrences[0].date, lastDate: occurrences[occurrences.length - 1].date };
}

const minutes = (hhmm: string) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));

/**
 * The client's already-scheduled workouts (cancelled ones do not count) that clash with the program's: same day and both
 * timed within `CONFLICT_WINDOW_MINUTES`, or same day with neither timed (two "sometime today" workouts). A timed
 * workout beside an untimed one is not a clash — the untimed one has no slot to collide with. No auto-shift: the trainer
 * is told, and decides.
 */
export function findConflicts(
  occurrences: ProgramOccurrence[],
  existing: Pick<TrainerCalendarSessionResponse, "scheduledFor" | "scheduledTime" | "status">[],
): { occurrence: ProgramOccurrence; with: (typeof existing)[number] }[] {
  const out: { occurrence: ProgramOccurrence; with: (typeof existing)[number] }[] = [];
  for (const o of occurrences) {
    for (const e of existing) {
      if (e.status === "CANCELLED" || e.scheduledFor !== o.date) continue;
      const bothUntimed = !o.time && !e.scheduledTime;
      const bothTimed = !!o.time && !!e.scheduledTime;
      if (bothUntimed || (bothTimed && Math.abs(minutes(o.time!) - minutes(e.scheduledTime!)) < CONFLICT_WINDOW_MINUTES)) {
        out.push({ occurrence: o, with: e });
        break;
      }
    }
  }
  return out;
}

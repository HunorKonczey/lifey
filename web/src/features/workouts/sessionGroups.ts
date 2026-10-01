import { activityFamilyOf } from "./activityType";
import type { WorkoutSessionResponse } from "./types";

/**
 * Week grouping for the sessions list (W3.2, W3-A) — the web port of the mobile `session_groups.dart` +
 * `week_summary.dart`. Weeks run Monday–Sunday in the viewer's local time. The web shows one group per
 * calendar week ("This week", "Last week", then dated ranges) — "today" is not split out as on the phone.
 */
export type WeekKind = "thisWeek" | "lastWeek" | "olderWeek";

export interface WeekSummary {
  /** Sessions that started in the week, finished or not. */
  count: number;
  /** Finished sessions' effective durations: moving time when tracked, else the wall-clock span. */
  seconds: number;
  /** Σ weight × reps over the week's sets, in kg. */
  volumeKg: number;
  /** DISTANCE and MACHINE cardio only — a game's distance is not comparable. */
  distanceMeters: number;
}

export interface SessionWeek {
  kind: WeekKind;
  /** Local-midnight Monday. */
  weekStart: Date;
  /** Local-midnight Sunday — the last day shown in the range label. */
  weekEnd: Date;
  /** In the order they came in (newest first when the input is). */
  sessions: WorkoutSessionResponse[];
  summary: WeekSummary;
}

/** Local midnight of the Monday of the week containing `day`. */
export function weekStartFor(day: Date): Date {
  const midnight = new Date(day.getFullYear(), day.getMonth(), day.getDate());
  const sinceMonday = (midnight.getDay() + 6) % 7;
  return new Date(midnight.getFullYear(), midnight.getMonth(), midnight.getDate() - sinceMonday);
}

function addDays(day: Date, days: number): Date {
  return new Date(day.getFullYear(), day.getMonth(), day.getDate() + days);
}

/** Seconds a finished session counts for; null while it is still running. */
export function effectiveSeconds(session: WorkoutSessionResponse): number | null {
  if (session.movingSeconds != null) return session.movingSeconds;
  if (session.finishedAt == null) return null;
  return Math.max(0, Math.round((new Date(session.finishedAt).getTime() - new Date(session.startedAt).getTime()) / 1000));
}

export function sessionVolumeKg(session: WorkoutSessionResponse): number {
  return session.sets.reduce((sum, set) => sum + set.weight * set.reps, 0);
}

export function summarizeSessions(sessions: readonly WorkoutSessionResponse[]): WeekSummary {
  let seconds = 0;
  let volumeKg = 0;
  let distanceMeters = 0;
  for (const s of sessions) {
    seconds += effectiveSeconds(s) ?? 0;
    volumeKg += sessionVolumeKg(s);
    const meters = s.cardio?.distanceMeters;
    if (s.sessionKind === "CARDIO" && s.activityType && meters != null) {
      const family = activityFamilyOf(s.activityType);
      if (family === "DISTANCE" || family === "MACHINE") distanceMeters += meters;
    }
  }
  return { count: sessions.length, seconds, volumeKg, distanceMeters };
}

/** Groups `sessions` (newest first) into calendar weeks; empty weeks are not returned. */
export function groupSessionsByWeek(sessions: readonly WorkoutSessionResponse[], now: Date): SessionWeek[] {
  const thisWeek = weekStartFor(now).getTime();
  const lastWeek = addDays(weekStartFor(now), -7).getTime();

  const weeks: SessionWeek[] = [];
  const byStart = new Map<number, SessionWeek>();
  for (const session of sessions) {
    const weekStart = weekStartFor(new Date(session.startedAt));
    const key = weekStart.getTime();
    let week = byStart.get(key);
    if (!week) {
      week = {
        kind: key === thisWeek ? "thisWeek" : key === lastWeek ? "lastWeek" : "olderWeek",
        weekStart,
        weekEnd: addDays(weekStart, 6),
        sessions: [],
        summary: { count: 0, seconds: 0, volumeKg: 0, distanceMeters: 0 },
      };
      byStart.set(key, week);
      weeks.push(week);
    }
    week.sessions.push(session);
  }
  for (const week of weeks) week.summary = summarizeSessions(week.sessions);
  return weeks;
}

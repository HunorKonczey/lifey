import type { TrainerCalendarSessionResponse } from "./types";

/** The hours the week grid always shows, even with nothing in them (07:00 – 20:00). */
export const DEFAULT_FIRST_HOUR = 7;
export const DEFAULT_LAST_HOUR = 20;
/** An empty stretch this long (hours) or longer folds into one "nincs esemény" row. */
export const MIN_COLLAPSED_RUN = 3;

export interface HourRow {
  kind: "hour";
  hour: number;
}
export interface GapRow {
  kind: "gap";
  /** First and last empty hour of the folded run, inclusive. */
  from: number;
  to: number;
}
export type GridRow = HourRow | GapRow;

/** Stable key of a folded run, for the "expanded" set. */
export const gapKey = (from: number, to: number) => `${from}-${to}`;

/** The hour (0–23) a session starts in, or null when it has no time of day. */
export function sessionHour(session: Pick<TrainerCalendarSessionResponse, "scheduledTime">): number | null {
  if (!session.scheduledTime) return null;
  const hour = Number(session.scheduledTime.slice(0, 2));
  return Number.isInteger(hour) && hour >= 0 && hour <= 23 ? hour : null;
}

/**
 * Splits a week's sessions into the timed ones, bucketed by day and hour (`"2026-09-29|18"`), and the untimed ones per
 * day — those have no place on an hour row and go to the "no time" row at the top. Inside a bucket the order is by time.
 */
export function bucketSessions(sessions: TrainerCalendarSessionResponse[]): {
  cells: Map<string, TrainerCalendarSessionResponse[]>;
  untimed: Map<string, TrainerCalendarSessionResponse[]>;
} {
  const cells = new Map<string, TrainerCalendarSessionResponse[]>();
  const untimed = new Map<string, TrainerCalendarSessionResponse[]>();
  const sorted = [...sessions].sort((a, b) => (a.scheduledTime ?? "").localeCompare(b.scheduledTime ?? "") || a.sessionId - b.sessionId);
  for (const s of sorted) {
    const hour = sessionHour(s);
    const map = hour == null ? untimed : cells;
    const key = hour == null ? s.scheduledFor : `${s.scheduledFor}|${hour}`;
    if (!map.has(key)) map.set(key, []);
    map.get(key)!.push(s);
  }
  return { cells, untimed };
}

/**
 * The rows of the week grid. The range is 07:00–20:00 widened to take in any session outside it; hours with an event
 * in any of the shown days are "occupied". A run of at least `MIN_COLLAPSED_RUN` unoccupied hours becomes one gap row
 * (unless the person expanded it); shorter runs stay as ordinary rows so the grid does not jump around for one hour.
 */
export function buildHourRows(
  occupied: ReadonlySet<number>,
  options: { first?: number; last?: number; expanded?: ReadonlySet<string>; minRun?: number } = {},
): GridRow[] {
  const minRun = options.minRun ?? MIN_COLLAPSED_RUN;
  const hours = [...occupied];
  const first = Math.min(options.first ?? DEFAULT_FIRST_HOUR, ...hours);
  const last = Math.max(options.last ?? DEFAULT_LAST_HOUR, ...hours);
  const rows: GridRow[] = [];
  let h = first;
  while (h <= last) {
    if (occupied.has(h)) {
      rows.push({ kind: "hour", hour: h });
      h += 1;
      continue;
    }
    let end = h;
    while (end + 1 <= last && !occupied.has(end + 1)) end += 1;
    const length = end - h + 1;
    if (length >= minRun && !options.expanded?.has(gapKey(h, end))) {
      rows.push({ kind: "gap", from: h, to: end });
    } else {
      for (let x = h; x <= end; x += 1) rows.push({ kind: "hour", hour: x });
    }
    h = end + 1;
  }
  return rows;
}

/** The set of hours that carry at least one timed session. */
export function occupiedHours(sessions: TrainerCalendarSessionResponse[]): Set<number> {
  const out = new Set<number>();
  for (const s of sessions) {
    const h = sessionHour(s);
    if (h != null) out.add(h);
  }
  return out;
}

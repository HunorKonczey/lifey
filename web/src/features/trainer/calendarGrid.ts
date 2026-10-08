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

// ─── Drag to move, Shift + drag to copy (W8.5b) ───

/** The slot a calendar cell stands for: its day and — for an hour cell — "HH:00", or no time for the "no time" row. */
export interface DropSlot {
  /** yyyy-MM-dd */
  date: string;
  /** "HH:00" for an hour cell, null for the "no time" row. */
  time: string | null;
}

export const slotKey = (slot: DropSlot) => `${slot.date}|${slot.time ?? ""}`;

/**
 * What a drop should do: nothing (dropped where it already is — same day and the same hour, or the same day for an
 * untimed event onto the "no time" row), or move / copy to the slot. A drop onto the day the event is already on, at
 * the same hour, is not a move: the event keeps its exact minutes.
 */
export function dropAction(
  session: Pick<TrainerCalendarSessionResponse, "scheduledFor" | "scheduledTime">,
  slot: DropSlot,
): "noop" | "place" {
  const hour = sessionHour(session);
  const sameHour = slot.time == null ? hour == null : hour != null && Number(slot.time.slice(0, 2)) === hour;
  return session.scheduledFor === slot.date && sameHour ? "noop" : "place";
}

/** The request body for the move endpoint: the slot's day, and its time as "HH:mm" (an untimed slot sends none). */
export function moveBody(slot: DropSlot): { scheduledFor: string; scheduledTime: string | null } {
  return { scheduledFor: slot.date, scheduledTime: slot.time };
}

// ─── "Move…" from the session peek (LIF-140): the keyboard / touch way to do what a drag does ───

/** How far ahead the backend lets an occurrence be scheduled or moved (`WorkoutScheduleServiceImpl.moveOccurrence`). */
export const MOVE_HORIZON_MONTHS = 3;

/**
 * Whether a day can be moved to, judged the way the backend does it: not before today, not later than today plus three
 * calendar months (the last day itself is allowed). `null` for a date that is not (yet) a valid yyyy-MM-dd.
 */
export function moveDateProblem(iso: string, today: string): "invalid" | "past" | "horizon" | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(iso)) return "invalid";
  const parsed = new Date(`${iso}T00:00:00`);
  if (Number.isNaN(parsed.getTime())) return "invalid";
  if (iso < today) return "past";
  // Java's LocalDate.plusMonths clamps to the end of a shorter month (30 Nov + 3 months = 28 Feb); Date#setMonth would
  // roll over into March, so the limit is built by hand.
  const [y, m, d] = today.split("-").map(Number);
  const index = y * 12 + (m - 1) + MOVE_HORIZON_MONTHS;
  const limitYear = Math.floor(index / 12);
  const limitMonth = (index % 12) + 1;
  const lastDay = new Date(limitYear, limitMonth, 0).getDate();
  const pad = (n: number) => String(n).padStart(2, "0");
  const limitIso = `${limitYear}-${pad(limitMonth)}-${pad(Math.min(d, lastDay))}`;
  return iso > limitIso ? "horizon" : null;
}

/** The slot a typed day and time stand for; an empty time is "no time of day". */
export function slotFromInput(date: string, time: string): DropSlot {
  return { date, time: time === "" ? null : time };
}

/** True when moving to this exact day and time (minutes included) would change nothing. */
export function isSameSlot(session: Pick<TrainerCalendarSessionResponse, "scheduledFor" | "scheduledTime">, slot: DropSlot): boolean {
  const current = session.scheduledTime ? session.scheduledTime.slice(0, 5) : null;
  return session.scheduledFor === slot.date && current === slot.time;
}

import { complianceFor } from "./compliance";
import { clientDisplayName } from "./components/ClientAvatar";
import type { TrainerCalendarSessionResponse, TrainerClientResponse, WeightTrendPoint } from "./types";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

export type AttentionKind = "inactive" | "unread" | "missed" | "record";

export interface AttentionItem {
  kind: AttentionKind;
  clientId: number;
  /** Days inactive, unread messages, missed workouts or new records — whichever the kind counts. */
  count: number;
  /** The last message's text for an "unread" item, when there is one. */
  preview?: string | null;
}

/** A conversation as far as triage needs it: who it is with, how many are unread, what was said last. */
export interface UnreadThread {
  clientId: number;
  unreadCount: number;
  lastMessage: string | null;
}

const KIND_RANK: Record<AttentionKind, number> = { inactive: 0, unread: 1, missed: 2, record: 3 };

/**
 * Everything that wants the trainer's eye today, in the order it should be read: inactive clients first (the one
 * thing a trainer cannot see from the inside), then unread messages, then missed workouts, then new records.
 * Within a kind the bigger number comes first, ties by name. One item per client per kind.
 */
export function attentionItems(clients: TrainerClientResponse[], threads: UnreadThread[], now: Date = new Date()): AttentionItem[] {
  const unread = new Map(threads.filter((t) => t.unreadCount > 0).map((t) => [t.clientId, t]));
  const items: AttentionItem[] = [];
  for (const c of clients) {
    const flags = complianceFor(c, now);
    if (flags.inactive) items.push({ kind: "inactive", clientId: c.clientId, count: flags.daysSinceLastLog });
    const thread = unread.get(c.clientId);
    if (thread) items.push({ kind: "unread", clientId: c.clientId, count: thread.unreadCount, preview: thread.lastMessage });
    if (flags.hasMissedWorkouts) items.push({ kind: "missed", clientId: c.clientId, count: flags.missedWorkouts });
    if (c.prCount7d > 0) items.push({ kind: "record", clientId: c.clientId, count: c.prCount7d });
  }
  const name = new Map(clients.map((c) => [c.clientId, clientDisplayName(c)]));
  return items.sort(
    (a, b) =>
      KIND_RANK[a.kind] - KIND_RANK[b.kind] ||
      b.count - a.count ||
      (name.get(a.clientId) ?? "").localeCompare(name.get(b.clientId) ?? ""),
  );
}

/**
 * The "Figyelem" sort: inactive clients (longest silent first), then those with unread messages, then those with
 * missed workouts, then everyone else by name.
 */
export function sortByAttention(clients: TrainerClientResponse[], threads: UnreadThread[], now: Date = new Date()): TrainerClientResponse[] {
  const unread = new Map(threads.map((t) => [t.clientId, t.unreadCount]));
  const rank = (c: TrainerClientResponse) => {
    const f = complianceFor(c, now);
    if (f.inactive) return 0;
    if ((unread.get(c.clientId) ?? 0) > 0) return 1;
    if (f.hasMissedWorkouts) return 2;
    return 3;
  };
  return [...clients].sort((a, b) => {
    const ra = rank(a);
    const rb = rank(b);
    if (ra !== rb) return ra - rb;
    if (ra === 0) return complianceFor(b, now).daysSinceLastLog - complianceFor(a, now).daysSinceLastLog;
    if (ra === 1) return (unread.get(b.clientId) ?? 0) - (unread.get(a.clientId) ?? 0);
    if (ra === 2) return b.missedWorkoutCount - a.missedWorkoutCount;
    return clientDisplayName(a).localeCompare(clientDisplayName(b));
  });
}

export type WeekDotStatus = "DONE" | "MISSED" | "UPCOMING";

export interface WeekSummary {
  /** Sessions scheduled this week (cancelled ones are not scheduled any more). */
  scheduled: number;
  done: number;
  /** One dot per scheduled session, in date order. */
  dots: WeekDotStatus[];
  /** The next session that has not happened yet (today counts), or null. */
  next: TrainerCalendarSessionResponse | null;
  /** ISO dates of the missed sessions this week. */
  missedDates: string[];
}

/** One client's training week from the trainer's calendar feed: how many were scheduled, done, missed, and what is next. */
export function weekSummary(sessions: TrainerCalendarSessionResponse[], clientId: number, weekStart: string, today: string): WeekSummary {
  const end = new Date(new Date(weekStart + "T00:00:00Z").getTime() + 6 * MS_PER_DAY).toISOString().slice(0, 10);
  const own = sessions
    .filter((s) => s.clientId === clientId && s.status !== "CANCELLED")
    .sort((a, b) => a.scheduledFor.localeCompare(b.scheduledFor) || (a.scheduledTime ?? "").localeCompare(b.scheduledTime ?? ""));
  const inWeek = own.filter((s) => s.scheduledFor >= weekStart && s.scheduledFor <= end);
  return {
    scheduled: inWeek.length,
    done: inWeek.filter((s) => s.status === "DONE").length,
    dots: inWeek.map((s) => (s.status === "DONE" ? "DONE" : s.status === "MISSED" ? "MISSED" : "UPCOMING")),
    next: own.find((s) => s.status === "UPCOMING" && s.scheduledFor >= today) ?? null,
    missedDates: inWeek.filter((s) => s.status === "MISSED").map((s) => s.scheduledFor),
  };
}

export type WeightTone = "good" | "bad" | "neutral";

export interface WeightChange {
  latestKg: number;
  /** Change over the window against its earliest point, in kg; null when there is only one point. */
  deltaKg: number | null;
  /** Toward the goal = good, away = bad, within ±0.1 kg or no goal known = neutral. */
  tone: WeightTone;
}

/**
 * The 30-day weight line of a client card. `goalKg` is optional — without a goal there is no "right" direction, so
 * the tone stays neutral rather than guessing. No points at all returns null (the card says "no weigh-in", not 0).
 */
export function weightChange(trend: WeightTrendPoint[], now: Date = new Date(), goalKg?: number | null, windowDays = 30): WeightChange | null {
  if (trend.length === 0) return null;
  const sorted = [...trend].sort((a, b) => a.date.localeCompare(b.date));
  const since = new Date(now.getTime() - windowDays * MS_PER_DAY).toISOString().slice(0, 10);
  const inWindow = sorted.filter((p) => p.date >= since);
  const latest = sorted[sorted.length - 1];
  if (inWindow.length < 2) return { latestKg: latest.weightKg, deltaKg: null, tone: "neutral" };
  const delta = Math.round((latest.weightKg - inWindow[0].weightKg) * 10) / 10;
  let tone: WeightTone = "neutral";
  if (goalKg != null && Math.abs(delta) >= 0.1) {
    const towardGoal = Math.sign(goalKg - inWindow[0].weightKg) === Math.sign(delta);
    tone = towardGoal ? "good" : "bad";
  }
  return { latestKg: latest.weightKg, deltaKg: delta, tone };
}

export type LastActivityKind = "none" | "today" | "yesterday" | "daysAgo";

/** What the card's "last activity" line should say: never, today, yesterday or N days ago (the inactive case). */
export function lastActivity(client: TrainerClientResponse, now: Date = new Date()): { kind: LastActivityKind; days: number } {
  if (!client.lastActivityAt) return { kind: "none", days: 0 };
  const days = complianceFor(client, now).daysSinceLastLog;
  return { kind: days === 0 ? "today" : days === 1 ? "yesterday" : "daysAgo", days };
}

export type ClientListSort = "attention" | "name" | "activity";

/** The clients page's three sorts: attention (see `sortByAttention`), name A–Z, or most recently active first (never-active last). */
export function sortForList(clients: TrainerClientResponse[], sort: ClientListSort, threads: UnreadThread[], now: Date = new Date()): TrainerClientResponse[] {
  if (sort === "attention") return sortByAttention(clients, threads, now);
  if (sort === "name") return [...clients].sort((a, b) => clientDisplayName(a).localeCompare(clientDisplayName(b)));
  return [...clients].sort((a, b) => (b.lastActivityAt ?? "").localeCompare(a.lastActivityAt ?? ""));
}

/**
 * Which items the strip's cards show: the first of each kind in reading order, so one inactive client does not crowd
 * out the unread message and the new record; any room left is filled with the next items in order.
 */
export function pickForStrip(items: AttentionItem[], max: number): AttentionItem[] {
  const firstOfKind: AttentionItem[] = [];
  const seen = new Set<AttentionKind>();
  for (const i of items) {
    if (!seen.has(i.kind)) {
      seen.add(i.kind);
      firstOfKind.push(i);
    }
  }
  const picked = firstOfKind.slice(0, max);
  for (const i of items) {
    if (picked.length >= max) break;
    if (!picked.includes(i)) picked.push(i);
  }
  return picked;
}

/**
 * The 7-day calorie average as a share of the client's goal, rounded: 1 823 of 1 900 → 96. Null when either number is
 * missing (no meals logged, or no goal set) — the card then shows the plain average instead of an invented 0 %.
 */
export function calorieCompliance(client: Pick<TrainerClientResponse, "avgCalories7d" | "dailyCalorieGoal">): number | null {
  const goal = client.dailyCalorieGoal;
  if (client.avgCalories7d == null || goal == null || goal <= 0) return null;
  return Math.round((client.avgCalories7d / goal) * 100);
}

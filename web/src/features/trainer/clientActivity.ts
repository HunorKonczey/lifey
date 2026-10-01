import { computePrHistory } from "@/features/workouts/personalRecords";
import type { MealResponse } from "@/features/nutrition/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";
import type { WeightResponse } from "@/features/weight/types";

export type ActivityKind = "meal" | "workout" | "weight";

export interface HeatCell {
  /** Local yyyy-MM-dd. */
  date: string;
  kinds: ActivityKind[];
  isToday: boolean;
  isFuture: boolean;
}

export interface HeatWeek {
  /** The Monday, local yyyy-MM-dd. */
  weekStart: string;
  cells: HeatCell[];
}

const pad = (n: number) => String(n).padStart(2, "0");

/** A date as local yyyy-MM-dd — the person's own day, not UTC's. */
export function dayKey(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function mondayOf(d: Date): Date {
  const out = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  out.setDate(out.getDate() - ((out.getDay() + 6) % 7));
  return out;
}

export interface ActivityInput {
  meals: MealResponse[];
  sessions: WorkoutSessionResponse[];
  weights: WeightResponse[];
}

/**
 * The logging heatmap of the overview (W7-B): the last four weeks Monday-first, ending with the current week, one
 * cell per day with the kinds of thing logged that day — meal, workout, weigh-in — in that fixed order. Days after
 * today are flagged `isFuture` and never carry dots. Time-of-day instants are bucketed into the viewer's local day.
 */
export function buildHeatmap(input: ActivityInput, today: Date, weeks = 4): HeatWeek[] {
  const byDay = new Map<string, Set<ActivityKind>>();
  const add = (key: string, kind: ActivityKind) => {
    if (!byDay.has(key)) byDay.set(key, new Set());
    byDay.get(key)!.add(kind);
  };
  for (const m of input.meals) add(dayKey(new Date(m.dateTime)), "meal");
  for (const s of input.sessions) add(dayKey(new Date(s.startedAt)), "workout");
  for (const w of input.weights) add(w.date, "weight");

  const todayKey = dayKey(today);
  const first = mondayOf(today);
  first.setDate(first.getDate() - 7 * (weeks - 1));
  const order: ActivityKind[] = ["meal", "workout", "weight"];

  return Array.from({ length: weeks }, (_, w) => {
    const weekStart = new Date(first);
    weekStart.setDate(first.getDate() + 7 * w);
    const cells: HeatCell[] = Array.from({ length: 7 }, (_, d) => {
      const day = new Date(weekStart);
      day.setDate(weekStart.getDate() + d);
      const key = dayKey(day);
      const isFuture = key > todayKey;
      const present = byDay.get(key);
      return { date: key, kinds: isFuture || !present ? [] : order.filter((k) => present.has(k)), isToday: key === todayKey, isFuture };
    });
    return { weekStart: dayKey(weekStart), cells };
  });
}

export type FeedEvent =
  | { kind: "record"; at: Date; exerciseName: string; weight: number; reps: number }
  | { kind: "workout"; at: Date; sessionId: number; name: string | null }
  | { kind: "meal"; at: Date; name: string | null }
  | { kind: "weight"; at: Date; weightKg: number };

/**
 * New strength records in the loaded sessions: heavier than anything the same exercise had before *within the loaded
 * history*. The first logged set of an exercise only sets the baseline — it is not announced as a record, since with
 * a page of sessions we cannot tell whether it beat something older.
 */
export function recordEvents(sessions: WorkoutSessionResponse[]): Extract<FeedEvent, { kind: "record" }>[] {
  const byExercise = new Map<number, { name: string; sets: { weight: number; reps: number; performedAt: Date }[] }>();
  for (const s of sessions) {
    if (s.sessionKind !== "STRENGTH") continue;
    for (const set of s.sets) {
      if (!byExercise.has(set.exerciseId)) byExercise.set(set.exerciseId, { name: set.exerciseName, sets: [] });
      byExercise.get(set.exerciseId)!.sets.push({ weight: set.weight, reps: set.reps, performedAt: new Date(set.performedAt) });
    }
  }
  const events: Extract<FeedEvent, { kind: "record" }>[] = [];
  for (const { name, sets } of byExercise.values()) {
    const ordered = sets.sort((a, b) => a.performedAt.getTime() - b.performedAt.getTime());
    const firstAt = ordered[0]?.performedAt.getTime();
    for (const e of computePrHistory(ordered)) {
      if (e.type !== "maxWeight" || e.performedAt.getTime() === firstAt) continue;
      events.push({ kind: "record", at: e.performedAt, exerciseName: name, weight: e.weight, reps: e.reps });
    }
  }
  return events;
}

/**
 * "Legutóbb": the latest events across records, workouts, meals and weigh-ins, newest first. Meals logged within the
 * same hour collapse to the latest one (a lunch is one line, not one per ingredient), and `limit` caps the list.
 */
export function buildFeed(input: ActivityInput, limit = 5): FeedEvent[] {
  const events: FeedEvent[] = [];
  events.push(...recordEvents(input.sessions));
  for (const s of input.sessions) events.push({ kind: "workout", at: new Date(s.startedAt), sessionId: s.id, name: s.templateName });
  const meals = [...input.meals].sort((a, b) => b.dateTime.localeCompare(a.dateTime));
  let lastMealAt: number | null = null;
  for (const m of meals) {
    const at = new Date(m.dateTime);
    if (lastMealAt !== null && lastMealAt - at.getTime() < 60 * 60 * 1000) continue;
    lastMealAt = at.getTime();
    events.push({ kind: "meal", at, name: m.name });
  }
  for (const w of input.weights) events.push({ kind: "weight", at: new Date(w.date + "T12:00:00"), weightKg: w.weight });
  return events.sort((a, b) => b.at.getTime() - a.at.getTime()).slice(0, limit);
}

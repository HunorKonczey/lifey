import type { WorkoutSessionResponse } from "./types";

/**
 * Personal records derived from history — a port of
 * `mobile/lib/features/workouts/domain/personal_record.dart`
 * (docs/38-personal-records-plan.md, W1.9) that keeps the *same definition* as
 * the backend's `trainer/PersonalRecordCounter.java` (the trainer client
 * card's "🏆 n PRs this week"): a record is never stored, it is found by
 * replaying history oldest-first, and a set breaks one when it is strictly
 * better than everything before it, for one of three kinds.
 */
export type PrType = "maxWeight" | "repsAtWeight" | "estimatedOneRm";

/** One previously logged set, as far as PR detection needs it. */
export interface PrSet {
  weight: number;
  reps: number;
  performedAt: Date;
}

/** Epley formula: weight × (1 + reps / 30). */
export function estimateOneRepMax(weight: number, reps: number): number {
  return weight * (1 + reps / 30);
}

/**
 * The "best so far" values a candidate set is compared against — never
 * includes the candidate itself. Purely derived from history, never persisted.
 */
export interface PrBaseline {
  /** Highest weight ever lifted (0 kg sets excluded); null until a weighted set exists. */
  maxWeight: number | null;
  /** Best estimated 1RM (0 kg sets excluded); null until a weighted set exists. */
  bestOneRm: number | null;
  /** Most reps ever done at each exact weight (0 kg included — a bodyweight rep record is
   *  meaningful). Weights come from typed input, never arithmetic, so exact equality is safe. */
  maxRepsByWeight: ReadonlyMap<number, number>;
}

export const EMPTY_BASELINE: PrBaseline = { maxWeight: null, bestOneRm: null, maxRepsByWeight: new Map() };

/** Returns a new baseline with `set` folded in. */
export function extendBaseline(baseline: PrBaseline, set: Pick<PrSet, "weight" | "reps">): PrBaseline {
  let maxWeight = baseline.maxWeight;
  let bestOneRm = baseline.bestOneRm;
  if (set.weight > 0) {
    if (maxWeight == null || set.weight > maxWeight) maxWeight = set.weight;
    const orm = estimateOneRepMax(set.weight, set.reps);
    if (bestOneRm == null || orm > bestOneRm) bestOneRm = orm;
  }
  const maxRepsByWeight = new Map(baseline.maxRepsByWeight);
  const current = maxRepsByWeight.get(set.weight);
  if (current == null || set.reps > current) maxRepsByWeight.set(set.weight, set.reps);
  return { maxWeight, bestOneRm, maxRepsByWeight };
}

/** A baseline from prior sets (order doesn't matter). */
export function baselineFromSets(sets: Iterable<Pick<PrSet, "weight" | "reps">>): PrBaseline {
  let baseline = EMPTY_BASELINE;
  for (const s of sets) baseline = extendBaseline(baseline, s);
  return baseline;
}

/**
 * Which record kinds a candidate (weight, reps) set breaks against `baseline`.
 * Strictly-greater: matching the existing best is not a record. A kind never
 * fires without a baseline value to beat — a never-before-seen weight is not a
 * "reps PR", and an all-bodyweight history has no max-weight / 1RM to beat.
 */
export function detectPrs(baseline: PrBaseline, candidate: { weight: number; reps: number }): PrType[] {
  const types: PrType[] = [];
  const { weight, reps } = candidate;

  if (weight > 0) {
    if (baseline.maxWeight != null && weight > baseline.maxWeight) types.push("maxWeight");
    if (baseline.bestOneRm != null && estimateOneRepMax(weight, reps) > baseline.bestOneRm) types.push("estimatedOneRm");
  }

  const prior = baseline.maxRepsByWeight.get(weight);
  if (prior != null && reps > prior) types.push("repsAtWeight");
  return types;
}

/** A single moment a record kind's running best increased. */
export interface PrEvent {
  type: PrType;
  weight: number;
  reps: number;
  performedAt: Date;
}

/** Walks `sets` (oldest first — the caller sorts) and records every increase of a running best. */
export function computePrHistory(sets: PrSet[]): PrEvent[] {
  const events: PrEvent[] = [];
  let baseline = EMPTY_BASELINE;
  for (const s of sets) {
    for (const type of detectPrs(baseline, s)) events.push({ type, weight: s.weight, reps: s.reps, performedAt: s.performedAt });
    baseline = extendBaseline(baseline, s);
  }
  return events;
}

/**
 * The same running-baseline walk, but one record list per input position — for
 * mapping results back onto a row (a session's live per-set badge), starting
 * from a real `baseline` (the exercise's history before this session).
 */
export function detectPrsInOrder(baseline: PrBaseline, sets: PrSet[]): PrType[][] {
  const result: PrType[][] = [];
  let running = baseline;
  for (const s of sets) {
    result.push(detectPrs(running, s));
    running = extendBaseline(running, s);
  }
  return result;
}

/** One logged set with the session it belongs to — the shape the backend counter takes. */
export interface SetFact {
  sessionId: number;
  sessionStartedAt: Date;
  exerciseId: number;
  weight: number;
  reps: number;
  performedAt: Date;
}

/**
 * The record kinds each session set, counted the way the backend does: sets of
 * one exercise within a session are judged against the running best, and a
 * session counts each kind **once per exercise** — three heavy sets in a row
 * that each beat the last are still one "heaviest set". `facts` must be oldest
 * session first and each session's sets in `performedAt` order (same contract as
 * `PersonalRecordCounter.countSince`).
 */
export function recordsBySession(facts: SetFact[]): Map<number, number> {
  const baselines = new Map<number, PrBaseline>();
  const counts = new Map<number, number>();

  let i = 0;
  while (i < facts.length) {
    const sessionId = facts[i].sessionId;
    let end = i;
    while (end < facts.length && facts[end].sessionId === sessionId) end++;

    const perExercise = new Map<number, Set<PrType>>();
    for (let j = i; j < end; j++) {
      const f = facts[j];
      const baseline = baselines.get(f.exerciseId) ?? EMPTY_BASELINE;
      const kinds = perExercise.get(f.exerciseId) ?? new Set<PrType>();
      for (const k of detectPrs(baseline, f)) kinds.add(k);
      perExercise.set(f.exerciseId, kinds);
      baselines.set(f.exerciseId, extendBaseline(baseline, f));
    }

    let total = 0;
    for (const kinds of perExercise.values()) total += kinds.size;
    counts.set(sessionId, total);
    i = end;
  }
  return counts;
}

/** Records set by sessions that started at or after `since` — the backend's `countSince`. */
export function countRecordsSince(facts: SetFact[], since: Date): number {
  const counts = recordsBySession(facts);
  const started = new Map(facts.map((f) => [f.sessionId, f.sessionStartedAt.getTime()]));
  let total = 0;
  for (const [sessionId, n] of counts) if ((started.get(sessionId) ?? 0) >= since.getTime()) total += n;
  return total;
}

/**
 * The replay's input from API sessions: finished strength sessions only (an
 * in-progress one isn't history yet, cardio has no sets), oldest first, each
 * session's sets by `performedAt`.
 */
export function setFactsFromSessions(sessions: WorkoutSessionResponse[]): SetFact[] {
  return sessions
    .filter((s) => s.sessionKind === "STRENGTH" && s.finishedAt != null)
    .sort((a, b) => new Date(a.startedAt).getTime() - new Date(b.startedAt).getTime() || a.id - b.id)
    .flatMap((s) =>
      [...s.sets]
        .sort((a, b) => new Date(a.performedAt).getTime() - new Date(b.performedAt).getTime())
        .map((set) => ({
          sessionId: s.id,
          sessionStartedAt: new Date(s.startedAt),
          exerciseId: set.exerciseId,
          weight: set.weight,
          reps: set.reps,
          performedAt: new Date(set.performedAt),
        })),
    );
}

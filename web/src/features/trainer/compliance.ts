import type { TrainerClientResponse } from "./types";

/** Flagged once a client hasn't logged anything (meal/water/workout/weight) in this many days. */
export const INACTIVITY_FLAG_DAYS = 3;

/** Flagged once a client hasn't logged their weight in this many days. */
export const WEIGHT_STALE_FLAG_DAYS = 7;

const MS_PER_DAY = 24 * 60 * 60 * 1000;

function daysSince(isoDate: string | null, fallbackIsoDate: string, now: Date): number {
  const reference = isoDate ?? fallbackIsoDate;
  const elapsedMs = now.getTime() - new Date(reference).getTime();
  return Math.max(0, Math.floor(elapsedMs / MS_PER_DAY));
}

export interface ComplianceFlags {
  daysSinceLastLog: number;
  daysSinceWeight: number;
  missedWorkouts: number;
  inactive: boolean;
  weightStale: boolean;
  hasMissedWorkouts: boolean;
  needsAttention: boolean;
}

/**
 * Raw facts (lastActivityAt/lastWeightAt/missedWorkoutCount) come from the
 * backend; thresholds and flag composition live here so ClientCard, the
 * dashboard's "needs attention" section and sorting all agree (docs/29).
 *
 * Brand-new clients fall back to `activeSince` for both "days since" figures
 * — a client who never logged anything only gets flagged once the threshold
 * has passed since they joined, not immediately on invite acceptance.
 */
export function complianceFor(client: TrainerClientResponse, now: Date = new Date()): ComplianceFlags {
  const daysSinceLastLog = daysSince(client.lastActivityAt, client.activeSince, now);
  const daysSinceWeight = daysSince(client.lastWeightAt, client.activeSince, now);
  const missedWorkouts = client.missedWorkoutCount;

  const inactive = daysSinceLastLog >= INACTIVITY_FLAG_DAYS;
  const weightStale = daysSinceWeight >= WEIGHT_STALE_FLAG_DAYS;
  const hasMissedWorkouts = missedWorkouts >= 1;

  return {
    daysSinceLastLog,
    daysSinceWeight,
    missedWorkouts,
    inactive,
    weightStale,
    hasMissedWorkouts,
    needsAttention: inactive || weightStale || hasMissedWorkouts,
  };
}

/** Least-active-first: worst inactivity, then most missed workouts. */
export function byLeastActiveFirst(a: TrainerClientResponse, b: TrainerClientResponse, now: Date = new Date()): number {
  const flagsA = complianceFor(a, now);
  const flagsB = complianceFor(b, now);
  return flagsB.daysSinceLastLog - flagsA.daysSinceLastLog || flagsB.missedWorkouts - flagsA.missedWorkouts;
}

/** Most missed workouts first. */
export function byMostMissedWorkouts(a: TrainerClientResponse, b: TrainerClientResponse): number {
  return b.missedWorkoutCount - a.missedWorkoutCount;
}

/** Weight overdue first. */
export function byWeightOverdue(a: TrainerClientResponse, b: TrainerClientResponse, now: Date = new Date()): number {
  return complianceFor(b, now).daysSinceWeight - complianceFor(a, now).daysSinceWeight;
}

/** "recent" keeps the backend's default order (respondedAt desc) — no re-sort. */
export type ClientSortOption = "recent" | "leastActive" | "mostMissed" | "weightOverdue";

/** Applies a `ClientSortOption` to an already-fetched client list — pure, no API params. */
export function sortClients(
  clients: TrainerClientResponse[],
  sort: ClientSortOption,
  now: Date = new Date(),
): TrainerClientResponse[] {
  switch (sort) {
    case "leastActive":
      return [...clients].sort((a, b) => byLeastActiveFirst(a, b, now));
    case "mostMissed":
      return [...clients].sort(byMostMissedWorkouts);
    case "weightOverdue":
      return [...clients].sort((a, b) => byWeightOverdue(a, b, now));
    case "recent":
      return clients;
  }
}

import { describe, it, expect } from "vitest";
import {
  complianceFor,
  byLeastActiveFirst,
  byMostMissedWorkouts,
  byWeightOverdue,
  sortClients,
  INACTIVITY_FLAG_DAYS,
  WEIGHT_STALE_FLAG_DAYS,
} from "./compliance";
import type { TrainerClientResponse } from "./types";

const NOW = new Date("2026-07-11T12:00:00Z");
const MS_PER_DAY = 24 * 60 * 60 * 1000;

function client(overrides: Partial<TrainerClientResponse> = {}): TrainerClientResponse {
  return {
    clientId: 1,
    clientEmail: "client@example.com",
    activeSince: "2026-06-01T00:00:00Z",
    weightTrend: [],
    assignedPlanCount: 0,
    workoutsPerWeek: 0,
    lastActivityAt: null,
    lastWeightAt: null,
    missedWorkoutCount: 0,
    ...overrides,
  };
}

describe("complianceFor", () => {
  it("never logged anything -> falls back to activeSince, not instantly flagged", () => {
    const flags = complianceFor(client({ activeSince: NOW.toISOString() }), NOW);

    expect(flags.daysSinceLastLog).toBe(0);
    expect(flags.daysSinceWeight).toBe(0);
    expect(flags.inactive).toBe(false);
    expect(flags.weightStale).toBe(false);
    expect(flags.needsAttention).toBe(false);
  });

  it("never logged anything, joined long ago -> flagged via activeSince fallback", () => {
    const longAgo = new Date(NOW.getTime() - 30 * MS_PER_DAY).toISOString();
    const flags = complianceFor(client({ activeSince: longAgo }), NOW);

    expect(flags.inactive).toBe(true);
    expect(flags.weightStale).toBe(true);
    expect(flags.needsAttention).toBe(true);
  });

  it("just under the inactivity threshold -> not flagged", () => {
    const lastActivityAt = new Date(NOW.getTime() - (INACTIVITY_FLAG_DAYS - 1) * MS_PER_DAY).toISOString();
    const flags = complianceFor(client({ lastActivityAt }), NOW);

    expect(flags.daysSinceLastLog).toBe(INACTIVITY_FLAG_DAYS - 1);
    expect(flags.inactive).toBe(false);
  });

  it("exactly at the inactivity threshold -> flagged", () => {
    const lastActivityAt = new Date(NOW.getTime() - INACTIVITY_FLAG_DAYS * MS_PER_DAY).toISOString();
    const flags = complianceFor(client({ lastActivityAt }), NOW);

    expect(flags.daysSinceLastLog).toBe(INACTIVITY_FLAG_DAYS);
    expect(flags.inactive).toBe(true);
    expect(flags.needsAttention).toBe(true);
  });

  it("just under the weight-stale threshold -> not flagged", () => {
    const lastWeightAt = new Date(NOW.getTime() - (WEIGHT_STALE_FLAG_DAYS - 1) * MS_PER_DAY).toISOString();
    const flags = complianceFor(client({ lastActivityAt: NOW.toISOString(), lastWeightAt }), NOW);

    expect(flags.weightStale).toBe(false);
  });

  it("exactly at the weight-stale threshold -> flagged", () => {
    const lastWeightAt = new Date(NOW.getTime() - WEIGHT_STALE_FLAG_DAYS * MS_PER_DAY).toISOString();
    const flags = complianceFor(client({ lastActivityAt: NOW.toISOString(), lastWeightAt }), NOW);

    expect(flags.weightStale).toBe(true);
    expect(flags.needsAttention).toBe(true);
  });

  it("one missed workout -> flagged", () => {
    const flags = complianceFor(
      client({ lastActivityAt: NOW.toISOString(), lastWeightAt: NOW.toISOString(), missedWorkoutCount: 1 }),
      NOW,
    );

    expect(flags.hasMissedWorkouts).toBe(true);
    expect(flags.needsAttention).toBe(true);
  });

  it("fully compliant client -> no flags", () => {
    const flags = complianceFor(
      client({ lastActivityAt: NOW.toISOString(), lastWeightAt: NOW.toISOString(), missedWorkoutCount: 0 }),
      NOW,
    );

    expect(flags.inactive).toBe(false);
    expect(flags.weightStale).toBe(false);
    expect(flags.hasMissedWorkouts).toBe(false);
    expect(flags.needsAttention).toBe(false);
  });
});

describe("sort comparators", () => {
  it("byLeastActiveFirst orders worst inactivity first, then most missed workouts", () => {
    const fresh = client({ clientId: 1, lastActivityAt: NOW.toISOString() });
    const staleWithFewMisses = client({
      clientId: 2,
      lastActivityAt: new Date(NOW.getTime() - 10 * MS_PER_DAY).toISOString(),
      missedWorkoutCount: 1,
    });
    const staleWithManyMisses = client({
      clientId: 3,
      lastActivityAt: new Date(NOW.getTime() - 10 * MS_PER_DAY).toISOString(),
      missedWorkoutCount: 5,
    });

    const sorted = [fresh, staleWithFewMisses, staleWithManyMisses].sort((a, b) => byLeastActiveFirst(a, b, NOW));

    expect(sorted.map((c) => c.clientId)).toEqual([3, 2, 1]);
  });

  it("byMostMissedWorkouts orders highest missed count first", () => {
    const a = client({ clientId: 1, missedWorkoutCount: 2 });
    const b = client({ clientId: 2, missedWorkoutCount: 5 });
    const c = client({ clientId: 3, missedWorkoutCount: 0 });

    const sorted = [a, b, c].sort(byMostMissedWorkouts);

    expect(sorted.map((x) => x.clientId)).toEqual([2, 1, 3]);
  });

  it("byWeightOverdue orders longest-overdue weight first", () => {
    const recent = client({ clientId: 1, lastWeightAt: NOW.toISOString() });
    const overdue = client({
      clientId: 2,
      lastWeightAt: new Date(NOW.getTime() - 20 * MS_PER_DAY).toISOString(),
    });

    const sorted = [recent, overdue].sort((a, b) => byWeightOverdue(a, b, NOW));

    expect(sorted.map((x) => x.clientId)).toEqual([2, 1]);
  });
});

describe("sortClients", () => {
  const a = client({
    clientId: 1,
    lastActivityAt: NOW.toISOString(),
    lastWeightAt: NOW.toISOString(),
    missedWorkoutCount: 1,
  });
  const b = client({
    clientId: 2,
    lastActivityAt: new Date(NOW.getTime() - 10 * MS_PER_DAY).toISOString(),
    lastWeightAt: new Date(NOW.getTime() - 20 * MS_PER_DAY).toISOString(),
    missedWorkoutCount: 5,
  });
  const list = [a, b];

  it("'recent' returns the list unchanged (backend order)", () => {
    expect(sortClients(list, "recent", NOW)).toEqual(list);
  });

  it("'leastActive' matches byLeastActiveFirst", () => {
    expect(sortClients(list, "leastActive", NOW).map((c) => c.clientId)).toEqual([2, 1]);
  });

  it("'mostMissed' matches byMostMissedWorkouts", () => {
    expect(sortClients(list, "mostMissed", NOW).map((c) => c.clientId)).toEqual([2, 1]);
  });

  it("'weightOverdue' matches byWeightOverdue", () => {
    expect(sortClients(list, "weightOverdue", NOW).map((c) => c.clientId)).toEqual([2, 1]);
  });

  it("does not mutate the input array", () => {
    const original = [...list];
    sortClients(list, "leastActive", NOW);
    expect(list).toEqual(original);
  });
});

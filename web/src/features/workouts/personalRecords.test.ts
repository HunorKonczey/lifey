import { describe, expect, it } from "vitest";
import {
  EMPTY_BASELINE,
  baselineFromSets,
  computePrHistory,
  countRecordsSince,
  detectPrs,
  detectPrsInOrder,
  estimateOneRepMax,
  extendBaseline,
  recordsBySession,
  setFactsFromSessions,
  type PrSet,
  type SetFact,
} from "./personalRecords";
import type { WorkoutSessionResponse } from "./types";

/**
 * Part 1 ports every case of
 * `mobile/test/features/workouts/domain/personal_record_test.dart`; part 2
 * ports every case of the backend's `PersonalRecordCounterTest.java` with the
 * same data and the same expected counts — that is what "the backend counter
 * and the TS function agree" means (W1.9): one definition, three
 * implementations, identical answers on identical fixtures.
 */

const day1 = new Date(2026, 6, 1);
const day2 = new Date(2026, 6, 8);
const day3 = new Date(2026, 6, 15);
const set = (weight: number, reps: number, performedAt: Date): PrSet => ({ weight, reps, performedAt });

describe("estimateOneRepMax", () => {
  it("applies the Epley formula", () => {
    expect(estimateOneRepMax(100, 10)).toBeCloseTo(133.33, 2);
    expect(estimateOneRepMax(100, 0)).toBe(100);
  });
});

describe("baselineFromSets", () => {
  it("empty history has no baseline values", () => {
    const b = baselineFromSets([]);
    expect(b.maxWeight).toBeNull();
    expect(b.bestOneRm).toBeNull();
    expect(b.maxRepsByWeight.size).toBe(0);
  });

  it("tracks max weight, best e1RM, and max reps per weight", () => {
    const b = baselineFromSets([set(80, 10, day1), set(100, 5, day2), set(80, 12, day3)]);
    expect(b.maxWeight).toBe(100);
    expect(b.bestOneRm).toBe(estimateOneRepMax(100, 5));
    expect(b.maxRepsByWeight.get(80)).toBe(12);
    expect(b.maxRepsByWeight.get(100)).toBe(5);
  });

  it("excludes 0 kg (bodyweight) sets from max weight and e1RM", () => {
    const b = baselineFromSets([set(0, 20, day1)]);
    expect(b.maxWeight).toBeNull();
    expect(b.bestOneRm).toBeNull();
    expect(b.maxRepsByWeight.get(0)).toBe(20);
  });
});

describe("extendBaseline", () => {
  it("folds a single set into an empty baseline the same as baselineFromSets", () => {
    const extended = extendBaseline(EMPTY_BASELINE, set(60, 8, day1));
    const from = baselineFromSets([set(60, 8, day1)]);
    expect(extended.maxWeight).toBe(from.maxWeight);
    expect(extended.bestOneRm).toBe(from.bestOneRm);
    expect([...extended.maxRepsByWeight]).toEqual([...from.maxRepsByWeight]);
  });

  it("running baseline advances across two sets in one session", () => {
    let b = extendBaseline(EMPTY_BASELINE, set(100, 5, day1));
    expect(b.maxWeight).toBe(100);
    b = extendBaseline(b, set(105, 5, day1));
    expect(b.maxWeight).toBe(105);
  });

  it("never mutates the baseline it was given", () => {
    const before = baselineFromSets([set(80, 8, day1)]);
    extendBaseline(before, set(80, 12, day2));
    expect(before.maxRepsByWeight.get(80)).toBe(8);
  });
});

describe("detectPrs", () => {
  it("no baseline -> no record fires for any type", () => {
    expect(detectPrs(EMPTY_BASELINE, { weight: 100, reps: 5 })).toEqual([]);
  });

  it("strictly greater weight is a max-weight PR; equal is not", () => {
    const b = baselineFromSets([set(100, 5, day1)]);
    expect(detectPrs(b, { weight: 105, reps: 5 })).toContain("maxWeight");
    expect(detectPrs(b, { weight: 100, reps: 5 })).not.toContain("maxWeight");
  });

  it("reps-at-weight requires a prior set at that exact weight", () => {
    const b = baselineFromSets([set(80, 8, day1)]);
    expect(detectPrs(b, { weight: 60, reps: 20 })).not.toContain("repsAtWeight"); // never-before-used weight
    expect(detectPrs(b, { weight: 80, reps: 9 })).toContain("repsAtWeight");
    expect(detectPrs(b, { weight: 80, reps: 8 })).not.toContain("repsAtWeight"); // equal reps
  });

  it("estimated 1RM PR fires only when it beats the prior best", () => {
    const b = baselineFromSets([set(100, 5, day1)]);
    expect(detectPrs(b, { weight: 100, reps: 8 })).toContain("estimatedOneRm");
    expect(detectPrs(b, { weight: 90, reps: 5 })).not.toContain("estimatedOneRm");
  });

  it("weight 0 sets are eligible only for reps-at-weight", () => {
    const b = baselineFromSets([set(0, 15, day1)]);
    expect(detectPrs(b, { weight: 0, reps: 20 })).toEqual(["repsAtWeight"]);
  });

  it("one set can break multiple record types at once", () => {
    const b = baselineFromSets([set(100, 5, day1)]);
    expect(detectPrs(b, { weight: 110, reps: 6 })).toEqual(expect.arrayContaining(["maxWeight", "estimatedOneRm"]));
  });
});

describe("computePrHistory", () => {
  it("empty history has no events", () => {
    expect(computePrHistory([])).toEqual([]);
  });

  it("first set ever logged is never a PR (no baseline to beat)", () => {
    expect(computePrHistory([set(100, 5, day1)])).toEqual([]);
  });

  it("a plateau (repeating the same set) produces no further events", () => {
    expect(computePrHistory([set(100, 5, day1), set(100, 5, day2), set(100, 5, day3)])).toEqual([]);
  });

  it("progressive overload produces an event per improvement", () => {
    const events = computePrHistory([set(100, 5, day1), set(105, 5, day2), set(105, 6, day3)]);
    const at = (d: Date) => events.filter((e) => e.performedAt === d).map((e) => e.type);
    expect(at(day2)).toEqual(expect.arrayContaining(["maxWeight", "estimatedOneRm"]));
    expect(at(day3)).toEqual(expect.arrayContaining(["repsAtWeight", "estimatedOneRm"]));
    expect(events.filter((e) => e.performedAt === day3 && e.type === "maxWeight")).toEqual([]);
  });

  it("interleaved types accumulate independently across weights", () => {
    const events = computePrHistory([set(60, 8, day1), set(80, 5, day2), set(60, 10, day3)]);
    // day3 is a reps-at-60kg PR even though 80kg was logged in between
    expect(events.filter((e) => e.performedAt === day3).map((e) => e.type)).toContain("repsAtWeight");
  });
});

describe("detectPrsInOrder", () => {
  it("empty input yields an empty result", () => {
    expect(detectPrsInOrder(EMPTY_BASELINE, [])).toEqual([]);
  });

  it("one record list per input position, in order", () => {
    const b = baselineFromSets([set(100, 5, day1)]);
    const result = detectPrsInOrder(b, [set(100, 5, day2), set(105, 5, day3)]);
    expect(result).toHaveLength(2);
    expect(result[0]).toEqual([]);
    expect(result[1]).toEqual(expect.arrayContaining(["maxWeight", "estimatedOneRm"]));
  });

  it("running baseline carries across positions within the call", () => {
    const result = detectPrsInOrder(EMPTY_BASELINE, [set(100, 5, day1), set(105, 5, day2)]);
    expect(result[0]).toEqual([]);
    expect(result[1].length).toBeGreaterThan(0);
  });
});

// ─── Part 2: the backend's PersonalRecordCounterTest, same data, same counts ───

const NOW = new Date("2026-09-25T12:00:00Z");
const WEEK_AGO = new Date(NOW.getTime() - 7 * 24 * 3600 * 1000);
const BENCH = 1;
const SQUAT = 2;

const daysAgo = (days: number) => new Date(NOW.getTime() - days * 24 * 3600 * 1000);

function fact(session: number, startedDaysAgo: number, exercise: number, weight: number, reps: number, minute: number): SetFact {
  const started = daysAgo(startedDaysAgo);
  return { sessionId: session, sessionStartedAt: started, exerciseId: exercise, weight, reps, performedAt: new Date(started.getTime() + minute * 60_000) };
}

describe("countRecordsSince (parity with PersonalRecordCounterTest)", () => {
  it("aFirstEverSetIsNotARecord", () => {
    expect(countRecordsSince([fact(1, 2, BENCH, 50, 8, 1)], WEEK_AGO)).toBe(0);
  });

  it("aHeavierSetAgainstEarlierHistoryIsOneOrMoreRecords", () => {
    const sets = [fact(1, 20, BENCH, 40, 8, 1), fact(2, 3, BENCH, 50, 8, 1)];
    // max weight + estimated 1RM; at the same reps nothing else
    expect(countRecordsSince(sets, WEEK_AGO)).toBe(2);
  });

  it("matchingTheBestIsNotARecord", () => {
    expect(countRecordsSince([fact(1, 20, BENCH, 50, 8, 1), fact(2, 3, BENCH, 50, 8, 1)], WEEK_AGO)).toBe(0);
  });

  it("moreRepsAtTheSameWeightIsARepsRecordAndOftenAnEstimatedOneRmToo", () => {
    // reps at 50 kg (8 -> 10) and estimated 1RM (63.3 -> 66.7); the weight itself did not move
    expect(countRecordsSince([fact(1, 20, BENCH, 50, 8, 1), fact(2, 3, BENCH, 50, 10, 1)], WEEK_AGO)).toBe(2);
  });

  it("threeSetsInARowThatEachBeatTheLastAreStillOneHeaviestSet", () => {
    const sets = [fact(1, 20, BENCH, 40, 5, 1), fact(2, 3, BENCH, 45, 5, 1), fact(2, 3, BENCH, 50, 5, 2), fact(2, 3, BENCH, 55, 5, 3)];
    // max weight once + estimated 1RM once, not three of each
    expect(countRecordsSince(sets, WEEK_AGO)).toBe(2);
  });

  it("eachExerciseCountsOnItsOwn", () => {
    const sets = [fact(1, 20, BENCH, 40, 5, 1), fact(1, 20, SQUAT, 60, 5, 2), fact(2, 3, BENCH, 50, 5, 1), fact(2, 3, SQUAT, 60, 5, 2)];
    expect(countRecordsSince(sets, WEEK_AGO)).toBe(2);
  });

  it("recordsBeforeTheWindowRaiseTheBarButAreNotCounted", () => {
    const sets = [fact(1, 30, BENCH, 40, 5, 1), fact(2, 20, BENCH, 60, 5, 1), fact(3, 2, BENCH, 55, 5, 1)];
    expect(countRecordsSince(sets, WEEK_AGO)).toBe(0);
  });

  it("aBodyweightHistoryHasNoWeightBaselineToBeat", () => {
    // only "more reps at 0 kg" fires
    expect(countRecordsSince([fact(1, 20, BENCH, 0, 10, 1), fact(2, 3, BENCH, 0, 12, 1)], WEEK_AGO)).toBe(1);
  });

  it("noSetsMeansNoRecords", () => {
    expect(countRecordsSince([], WEEK_AGO)).toBe(0);
  });
});

describe("recordsBySession / setFactsFromSessions", () => {
  it("gives each session its own record count — the chip on the row that set it", () => {
    const counts = recordsBySession([fact(1, 20, BENCH, 40, 8, 1), fact(2, 10, BENCH, 50, 8, 1), fact(3, 3, BENCH, 50, 8, 1)]);
    expect(counts.get(1)).toBe(0);
    expect(counts.get(2)).toBe(2); // heavier: max weight + e1RM
    expect(counts.get(3)).toBe(0); // matched, not beat
  });

  function session(over: Partial<WorkoutSessionResponse> & { id: number; startedAt: string }): WorkoutSessionResponse {
    return {
      finishedAt: "2026-09-20T19:00:00Z",
      exercises: [],
      sets: [],
      activeCalories: null,
      averageHeartRate: null,
      healthWorkoutId: null,
      templateId: null,
      templateName: null,
      rpe: null,
      feedbackNote: null,
      trainerComment: null,
      trainerCommentAt: null,
      sessionKind: "STRENGTH",
      activityType: null,
      movingSeconds: null,
      cardio: null,
      splits: [],
      waypoints: [],
      ...over,
    };
  }
  const s = (exerciseId: number, weight: number, reps: number, at: string) => ({ exerciseId, exerciseName: "", weight, reps, performedAt: at });

  it("turns API sessions into facts: strength and finished only, oldest session first, sets by time", () => {
    const sessions = [
      session({ id: 3, startedAt: "2026-09-22T18:00:00Z", sets: [s(1, 55, 5, "2026-09-22T18:20:00Z"), s(1, 50, 5, "2026-09-22T18:05:00Z")] }),
      session({ id: 1, startedAt: "2026-09-10T18:00:00Z", sets: [s(1, 40, 5, "2026-09-10T18:05:00Z")] }),
      session({ id: 2, startedAt: "2026-09-15T18:00:00Z", sessionKind: "CARDIO", sets: [s(1, 999, 99, "2026-09-15T18:05:00Z")] }),
      session({ id: 4, startedAt: "2026-09-23T18:00:00Z", finishedAt: null, sets: [s(1, 100, 5, "2026-09-23T18:05:00Z")] }),
    ];
    const facts = setFactsFromSessions(sessions);
    expect(facts.map((f) => [f.sessionId, f.weight])).toEqual([
      [1, 40],
      [3, 50],
      [3, 55],
    ]);
    // …so session 3's two heavier sets are one max-weight + one e1RM record
    expect(recordsBySession(facts).get(3)).toBe(2);
  });
});

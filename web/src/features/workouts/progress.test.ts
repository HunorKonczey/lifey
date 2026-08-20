import { describe, it, expect } from "vitest";
import { previousSets, computeWorkoutProgress } from "./progress";
import type { WorkoutSessionResponse } from "./types";

let nextId = 1;

function strengthSession(
  overrides: Partial<WorkoutSessionResponse> & { templateId?: number | null } = {},
): WorkoutSessionResponse {
  const id = nextId++;
  return {
    id,
    startedAt: new Date(2026, 5, 15 - id, 9, 0, 0).toISOString(),
    finishedAt: new Date(2026, 5, 15 - id, 9, 45, 0).toISOString(),
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
    ...overrides,
  };
}

/**
 * A finished cardio session — `sets: []` and `exercises: []` always (docs/cardio/52 §3.3), the
 * same shape `computeWorkoutProgress`/`previousSets` must not choke on.
 */
function cardioSession(): WorkoutSessionResponse {
  return strengthSession({ sessionKind: "CARDIO", activityType: "RUNNING", templateId: null });
}

describe("previousSets — cardio sessions never surface as a 'previous' set", () => {
  it("a cardio session interleaved in history is skipped (empty sets means it never matches)", () => {
    const current = strengthSession({ id: 100 });
    const cardio = cardioSession();
    const older = strengthSession({ sets: [{ exerciseId: 5, exerciseName: "Bench", reps: 8, weight: 60, performedAt: current.startedAt }] });
    const history = [current, cardio, older];

    const result = previousSets(history, current.id, 5, null);
    expect(result).toHaveLength(1);
    expect(result[0].weight).toBe(60);
  });

  it("a history of only cardio sessions never produces a previous set", () => {
    const current = strengthSession({ id: 200 });
    const history = [current, cardioSession(), cardioSession(), cardioSession()];
    expect(previousSets(history, current.id, 5, null)).toEqual([]);
  });

  it("a cardio session sharing no templateId still doesn't leak into the template-scoped search", () => {
    const current = strengthSession({ id: 300, templateId: 9 });
    const cardio = cardioSession(); // templateId always null for cardio
    const sameTemplate = strengthSession({
      templateId: 9,
      sets: [{ exerciseId: 5, exerciseName: "Bench", reps: 10, weight: 70, performedAt: current.startedAt }],
    });
    const result = previousSets([current, cardio, sameTemplate], current.id, 5, 9);
    expect(result).toHaveLength(1);
    expect(result[0].weight).toBe(70);
  });
});

describe("computeWorkoutProgress — a cardio session in history doesn't corrupt the score", () => {
  it("computes the same score whether or not a cardio session sits in history", () => {
    const current = strengthSession({ id: 400 });
    const prior = strengthSession({
      sets: [{ exerciseId: 5, exerciseName: "Bench", reps: 8, weight: 60, performedAt: current.startedAt }],
    });
    const drafts = [{ exerciseId: 5, weight: 65, reps: 8, done: true }];
    const exercises = [{ exerciseId: 5, exerciseName: "Bench" }];
    const formatWeight = (n: number) => n.toFixed(1);

    const withoutNoise = computeWorkoutProgress(current, drafts, [current, prior], exercises, formatWeight, "reps", "kg");
    const withNoise = computeWorkoutProgress(
      current, drafts, [current, cardioSession(), prior, cardioSession()], exercises, formatWeight, "reps", "kg",
    );

    expect(withNoise.score).toBe(withoutNoise.score);
    expect(withNoise.improvements).toEqual(withoutNoise.improvements);
  });

  it("doesn't throw when every session in history is cardio (empty exercises/sets)", () => {
    const current = strengthSession({ id: 500 });
    const history = [current, cardioSession(), cardioSession()];
    const drafts = [{ exerciseId: 5, weight: 65, reps: 8, done: true }];
    const exercises = [{ exerciseId: 5, exerciseName: "Bench" }];
    expect(() => computeWorkoutProgress(current, drafts, history, exercises, (n) => `${n}`, "reps", "kg")).not.toThrow();
  });
});

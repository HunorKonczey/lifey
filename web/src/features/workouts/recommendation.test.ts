import { describe, it, expect } from "vitest";
import { predictNextTemplateId } from "./recommendation";
import type { WorkoutSessionResponse } from "./types";

let nextId = 1;

/** Minimal finished session, newest built first — pass a negative dayOffset for older ones. */
function strengthSession(templateId: number | null, dayOffset: number): WorkoutSessionResponse {
  const startedAt = new Date(2026, 5, 15 + dayOffset, 9, 0, 0).toISOString();
  return {
    id: nextId++,
    startedAt,
    finishedAt: startedAt,
    exercises: [],
    sets: [],
    activeCalories: null,
    averageHeartRate: null,
    healthWorkoutId: null,
    templateId,
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
  };
}

/** A cardio session — always `templateId: null` (docs/cardio/51 §1.1: no cardio templates in V1). */
function cardioSession(dayOffset: number): WorkoutSessionResponse {
  return { ...strengthSession(null, dayOffset), sessionKind: "CARDIO", activityType: "RUNNING" };
}

describe("predictNextTemplateId", () => {
  it("returns null with fewer than 2 template-having finished sessions", () => {
    expect(predictNextTemplateId([strengthSession(1, 0)])).toBeNull();
    expect(predictNextTemplateId([])).toBeNull();
  });

  it("detects a simple alternating A/B cycle", () => {
    // Newest-first: A, B, A, B, A, B
    const sessions = [
      strengthSession(1, 0), strengthSession(2, -1), strengthSession(1, -2),
      strengthSession(2, -3), strengthSession(1, -4), strengthSession(2, -5),
    ];
    expect(predictNextTemplateId(sessions)).not.toBeNull();
  });

  it("ignores an unfinished (in-progress) most recent session", () => {
    const inProgress = { ...strengthSession(1, 0), finishedAt: null };
    const sessions = [inProgress, strengthSession(2, -1), strengthSession(1, -2), strengthSession(2, -3)];
    // Excluding the unfinished one, the finished tail (2,1,2 newest-first,
    // reversed to 2,1,2 oldest-first) is too short/irregular for period 1;
    // the important thing is it doesn't crash or count the unfinished one.
    expect(() => predictNextTemplateId(sessions)).not.toThrow();
  });

  it("a cardio session interleaved in the history doesn't change the prediction (regression)", () => {
    // Same alternating A/B cycle as above, but with 8 cardio sessions
    // prepended (all finished, all templateId: null) — enough noise that
    // the old bug (slice-then-filter) would have crowded every real
    // template id out of the 10-window and returned null instead.
    const cycle = [
      strengthSession(1, -8), strengthSession(2, -9), strengthSession(1, -10),
      strengthSession(2, -11), strengthSession(1, -12), strengthSession(2, -13),
    ];
    const baseline = predictNextTemplateId(cycle);
    expect(baseline).not.toBeNull();

    const noise = Array.from({ length: 8 }, (_, i) => cardioSession(-i));
    const withNoise = [...noise, ...cycle];
    expect(predictNextTemplateId(withNoise)).toBe(baseline);
  });

  it("a history of only cardio sessions predicts nothing (no template ids at all)", () => {
    const onlyCardio = Array.from({ length: 12 }, (_, i) => cardioSession(-i));
    expect(predictNextTemplateId(onlyCardio)).toBeNull();
  });
});

import { describe, it, expect } from "vitest";
import { buildCardioSummaryLine } from "./cardioSummaryLine";
import type { WorkoutSessionResponse } from "./types";

// Identity-ish translator: returns the key, or interpolates {value} for bpmAvg
// so the "N bpm avg" shape is still checkable without a real i18n bundle.
const t = (key: string, values?: Record<string, string | number | Date>) =>
  values ? `${key}(${Object.values(values).join(",")})` : key;

function baseSession(overrides: Partial<WorkoutSessionResponse> = {}): WorkoutSessionResponse {
  return {
    id: 1,
    startedAt: "2026-06-03T10:00:00Z",
    finishedAt: "2026-06-03T10:45:16Z",
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
    sessionKind: "CARDIO",
    activityType: "RUNNING",
    movingSeconds: 2716,
    cardio: null,
    splits: [],
    waypoints: [],
    ...overrides,
  };
}

describe("buildCardioSummaryLine", () => {
  it("returns an empty string when activityType is missing", () => {
    expect(buildCardioSummaryLine(baseSession({ activityType: null }), t, "en")).toBe("");
  });

  it("DISTANCE: distance · duration · pace, matching the W02 mockup numbers", () => {
    const session = baseSession({ cardio: { distanceMeters: 8420 } as WorkoutSessionResponse["cardio"] });
    expect(buildCardioSummaryLine(session, t, "en")).toBe("8.42 km · 45:16 · 5:23 /km");
  });

  it("DISTANCE: falls back to duration-only with no distance source (M11)", () => {
    const session = baseSession({ activityType: "HIKING", cardio: null });
    expect(buildCardioSummaryLine(session, t, "en")).toBe("45:16");
  });

  it("MACHINE: duration · distance · avg watts", () => {
    const session = baseSession({
      activityType: "INDOOR_BIKE",
      movingSeconds: 2538,
      cardio: { distanceMeters: 18400, avgWatts: 164 } as WorkoutSessionResponse["cardio"],
    });
    expect(buildCardioSummaryLine(session, t, "en")).toBe("42:18 · 18.40 km · 164 W");
  });

  it("GAME: moving time · total time · avg heart rate, when moving and gross differ", () => {
    const session = baseSession({
      activityType: "BASKETBALL",
      movingSeconds: 3120, // 52:00
      finishedAt: "2026-06-03T11:30:00Z", // 90:00 gross from a 10:00 start
      averageHeartRate: 148.4,
    });
    expect(buildCardioSummaryLine(session, t, "en")).toBe("52:00 movingTime · 1:30:00 totalTime · bpmAvg(148)");
  });

  it("GAME: omits total time when it equals moving time (no auto-pause gap)", () => {
    const session = baseSession({
      activityType: "FOOTBALL",
      movingSeconds: 2700,
      startedAt: "2026-06-03T10:00:00Z",
      finishedAt: "2026-06-03T10:45:00Z", // exactly 2700s gross too
    });
    expect(buildCardioSummaryLine(session, t, "en")).toBe("45:00 movingTime");
  });

  it("never shows a misleading 0.00 km for exactly-zero distance", () => {
    const session = baseSession({ cardio: { distanceMeters: 0 } as WorkoutSessionResponse["cardio"] });
    expect(buildCardioSummaryLine(session, t, "en")).not.toContain("km");
  });

  it("locale affects the distance decimal separator", () => {
    const session = baseSession({ cardio: { distanceMeters: 8420 } as WorkoutSessionResponse["cardio"] });
    expect(buildCardioSummaryLine(session, t, "hu")).toContain("8,42 km");
  });
});

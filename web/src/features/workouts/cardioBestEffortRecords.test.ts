import { describe, it, expect } from "vitest";
import { detectBestEffortRecords } from "./cardioBestEffortRecords";
import type { WorkoutSessionResponse, CardioDetailsResponse } from "./types";

let nextId = 1;

function cardio(overrides: Partial<CardioDetailsResponse> = {}): CardioDetailsResponse {
  return {
    distanceMeters: null, elevationGainMeters: null, elevationLossMeters: null, maxAltitudeMeters: null,
    steps: null, avgCadence: null, maxCadence: null,
    best1kSeconds: null, best5kSeconds: null, best10kSeconds: null,
    avgWatts: null, maxWatts: null, resistanceLevel: null, deviceCalories: null, maxHeartRate: null,
    hrZone1Seconds: null, hrZone2Seconds: null, hrZone3Seconds: null, hrZone4Seconds: null, hrZone5Seconds: null,
    intensity: null, venue: null, gameFormat: null, scorePoints: null, scoreAssists: null, scoreRebounds: null,
    distanceSource: null, caloriesSource: null, routePolyline: null, routePointCount: null,
    backpackWeightKg: null, avgGapSecondsPerKm: null,
    weatherTempC: null, weatherWindKph: null, weatherPrecipMm: null, weatherCondition: null,
    ...overrides,
  };
}

function session(overrides: Partial<WorkoutSessionResponse> = {}): WorkoutSessionResponse {
  return {
    id: nextId++,
    startedAt: "2026-06-01T10:00:00Z",
    finishedAt: "2026-06-01T10:45:00Z",
    exercises: [], sets: [],
    activeCalories: null, averageHeartRate: null, healthWorkoutId: null,
    templateId: null, templateName: null, rpe: null, feedbackNote: null,
    trainerComment: null, trainerCommentAt: null,
    sessionKind: "CARDIO", activityType: "RUNNING", movingSeconds: 2700,
    cardio: cardio(), splits: [], waypoints: [],
    ...overrides,
  };
}

describe("detectBestEffortRecords", () => {
  it("returns no records for the very first run (nothing to beat)", () => {
    const target = session({ finishedAt: "2026-06-01T10:45:00Z", cardio: cardio({ best1kSeconds: 240 }) });
    expect(detectBestEffortRecords([target], target)).toEqual(new Set());
  });

  it("flags a distance strictly faster than every prior run", () => {
    const prior = session({ finishedAt: "2026-05-01T10:00:00Z", cardio: cardio({ best1kSeconds: 260 }) });
    const target = session({ finishedAt: "2026-06-01T10:45:00Z", cardio: cardio({ best1kSeconds: 240 }) });
    expect(detectBestEffortRecords([prior, target], target)).toEqual(new Set(["1k"]));
  });

  it("does not flag a distance that only ties the prior best", () => {
    const prior = session({ finishedAt: "2026-05-01T10:00:00Z", cardio: cardio({ best1kSeconds: 240 }) });
    const target = session({ finishedAt: "2026-06-01T10:45:00Z", cardio: cardio({ best1kSeconds: 240 }) });
    expect(detectBestEffortRecords([prior, target], target)).toEqual(new Set());
  });

  it("does not flag a distance slower than the prior best", () => {
    const prior = session({ finishedAt: "2026-05-01T10:00:00Z", cardio: cardio({ best1kSeconds: 240 }) });
    const target = session({ finishedAt: "2026-06-01T10:45:00Z", cardio: cardio({ best1kSeconds: 260 }) });
    expect(detectBestEffortRecords([prior, target], target)).toEqual(new Set());
  });

  it("evaluates 1k/5k/10k independently", () => {
    const prior = session({
      finishedAt: "2026-05-01T10:00:00Z",
      cardio: cardio({ best1kSeconds: 240, best5kSeconds: 1300, best10kSeconds: 2800 }),
    });
    const target = session({
      finishedAt: "2026-06-01T10:45:00Z",
      // Beats 1k and 10k, ties 5k.
      cardio: cardio({ best1kSeconds: 235, best5kSeconds: 1300, best10kSeconds: 2750 }),
    });
    expect(detectBestEffortRecords([prior, target], target)).toEqual(new Set(["1k", "10k"]));
  });

  it("ignores a later session when computing the baseline", () => {
    const prior = session({ finishedAt: "2026-05-01T10:00:00Z", cardio: cardio({ best1kSeconds: 260 }) });
    const target = session({ finishedAt: "2026-06-01T10:45:00Z", cardio: cardio({ best1kSeconds: 240 }) });
    const later = session({ finishedAt: "2026-07-01T10:00:00Z", cardio: cardio({ best1kSeconds: 200 }) });
    // A later, faster run must not retroactively erase target's record.
    expect(detectBestEffortRecords([prior, target, later], target)).toEqual(new Set(["1k"]));
  });

  it("ignores a WALKING or HIKING session's best effort when building the baseline (RUNNING only, mirrors CardioPrType.fastest1k.appliesTo)", () => {
    const priorRun = session({ finishedAt: "2026-04-01T10:00:00Z", cardio: cardio({ best1kSeconds: 250 }) });
    const fastHike = session({
      activityType: "HIKING",
      finishedAt: "2026-05-01T10:00:00Z",
      cardio: cardio({ best1kSeconds: 200 }), // faster than target, but must not count
    });
    const target = session({ finishedAt: "2026-06-01T10:45:00Z", cardio: cardio({ best1kSeconds: 240 }) });
    // 240 beats priorRun's 250 → a record. If fastHike's 200 wrongly counted
    // toward the baseline, 240 would not beat it and this would be empty.
    expect(detectBestEffortRecords([priorRun, fastHike, target], target)).toEqual(new Set(["1k"]));
  });

  it("returns no records for a non-RUNNING target, even with a slower prior run", () => {
    const prior = session({ finishedAt: "2026-05-01T10:00:00Z", cardio: cardio({ best1kSeconds: 260 }) });
    const target = session({
      activityType: "HIKING",
      finishedAt: "2026-06-01T10:45:00Z",
      cardio: cardio({ best1kSeconds: 240 }),
    });
    expect(detectBestEffortRecords([prior, target], target)).toEqual(new Set());
  });

  it("returns no records for an unfinished session", () => {
    const target = session({ finishedAt: null, cardio: cardio({ best1kSeconds: 240 }) });
    expect(detectBestEffortRecords([target], target)).toEqual(new Set());
  });

  it("excludes the target itself from its own baseline (by id, not just date)", () => {
    // Same session object appearing twice in the list (e.g. a stale query
    // cache entry) must not let it beat itself.
    const target = session({ finishedAt: "2026-06-01T10:45:00Z", cardio: cardio({ best1kSeconds: 240 }) });
    expect(detectBestEffortRecords([target, target], target)).toEqual(new Set());
  });
});

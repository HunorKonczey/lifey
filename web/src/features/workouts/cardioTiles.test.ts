import { describe, it, expect } from "vitest";
import { buildCardioTiles } from "./cardioTiles";
import type { WorkoutSessionResponse } from "./types";

// Identity translator: returns the key itself, so assertions read the label
// key directly rather than a hardcoded EN/HU string.
const t = (key: string) => key;

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
    ...overrides,
  };
}

describe("buildCardioTiles — DISTANCE family", () => {
  it("shows distance, duration, and pace when distance is recorded", () => {
    const session = baseSession({ cardio: { distanceMeters: 8420 } as WorkoutSessionResponse["cardio"] });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toEqual([
      { label: "cardioDistanceLabel", value: "8.42 km", icon: "route" },
      { label: "cardioDurationLabel", value: "45:16", icon: "schedule" },
      { label: "cardioPaceLabel", value: "5:23 /km", icon: "speed" },
    ]);
  });

  it("falls back to duration-only when there's no distance source (M11)", () => {
    const session = baseSession({ activityType: "HIKING", cardio: null });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toEqual([{ label: "cardioDurationLabel", value: "45:16", icon: "schedule" }]);
  });

  it("adds an elevation-gain tile when present", () => {
    const session = baseSession({
      activityType: "HIKING",
      cardio: { distanceMeters: 5000, elevationGainMeters: 312.4 } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toContainEqual({ label: "cardioElevationGainLabel", value: "312 m", icon: "terrain" });
  });

  it("never shows a misleading 0.00 km when distance is exactly zero", () => {
    const session = baseSession({ cardio: { distanceMeters: 0 } as WorkoutSessionResponse["cardio"] });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles.find((tile) => tile.icon === "route")).toBeUndefined();
  });
});

describe("buildCardioTiles — MACHINE family", () => {
  it("shows moving time, distance, watts, cadence, resistance, calories", () => {
    const session = baseSession({
      activityType: "INDOOR_BIKE",
      movingSeconds: 2538,
      cardio: {
        distanceMeters: 18400, avgWatts: 164.3, avgCadence: 82.1, resistanceLevel: 6, deviceCalories: 421.9,
      } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toEqual([
      { label: "cardioMovingTimeLabel", value: "42:18", icon: "schedule" },
      { label: "cardioDistanceLabel", value: "18.40 km", icon: "route" },
      { label: "cardioAvgWattsLabel", value: "164 W", icon: "bolt" },
      { label: "cardioAvgCadenceLabel", value: "82 rpm", icon: "autorenew" },
      { label: "cardioResistanceLabel", value: "6", icon: "tune" },
      { label: "cardioDeviceCaloriesLabel", value: "422 kcal", icon: "local_fire_department" },
    ]);
  });

  it("always shows moving time and a distance tile (em-dash when absent)", () => {
    const session = baseSession({ activityType: "INDOOR_BIKE", cardio: null });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toEqual([
      { label: "cardioMovingTimeLabel", value: "45:16", icon: "schedule" },
      { label: "cardioDistanceLabel", value: "—", icon: "route" },
    ]);
  });
});

describe("buildCardioTiles — GAME family", () => {
  it("shows playing time only when no cardio details were recorded", () => {
    const session = baseSession({ activityType: "BASKETBALL", movingSeconds: 3120, cardio: null });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toEqual([{ label: "cardioPlayingTimeLabel", value: "52:00", icon: "schedule" }]);
  });

  it("adds venue, intensity, and score when present", () => {
    const session = baseSession({
      activityType: "BASKETBALL",
      movingSeconds: 3120,
      cardio: { venue: "INDOOR", intensity: 4, scorePoints: 18 } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toEqual([
      { label: "cardioPlayingTimeLabel", value: "52:00", icon: "schedule" },
      { label: "cardioVenueLabel", value: "cardioVenueIndoor", icon: "place" },
      { label: "cardioIntensityLabel", value: "4/5", icon: "whatshot" },
      { label: "cardioScoreLabel", value: "18", icon: "scoreboard" },
    ]);
  });

  it("maps OUTDOOR venue to the outdoor label", () => {
    const session = baseSession({
      activityType: "FOOTBALL",
      cardio: { venue: "OUTDOOR" } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toContainEqual({ label: "cardioVenueLabel", value: "cardioVenueOutdoor", icon: "place" });
  });

  it("treats OTHER_CARDIO (the escape-hatch type) as GAME", () => {
    const session = baseSession({ activityType: "OTHER_CARDIO", movingSeconds: 600 });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toEqual([{ label: "cardioPlayingTimeLabel", value: "10:00", icon: "schedule" }]);
  });
});

describe("buildCardioTiles — duration fallback", () => {
  it("uses the gross wall-clock span when movingSeconds is absent", () => {
    const session = baseSession({ activityType: "HIKING", movingSeconds: null, cardio: null });
    const tiles = buildCardioTiles(session, t, "en");
    // 10:00:00Z → 10:45:16Z = 2716s, same as the movingSeconds case above.
    expect(tiles).toEqual([{ label: "cardioDurationLabel", value: "45:16", icon: "schedule" }]);
  });

  it("shows an em-dash when neither movingSeconds nor finishedAt is available (still running)", () => {
    const session = baseSession({ activityType: "HIKING", movingSeconds: null, finishedAt: null, cardio: null });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toEqual([{ label: "cardioDurationLabel", value: "—", icon: "schedule" }]);
  });
});

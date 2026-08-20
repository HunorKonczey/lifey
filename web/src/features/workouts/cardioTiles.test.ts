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
    waypoints: [],
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
    const session = baseSession({ activityType: "WALKING", cardio: null });
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

  it("shows peak altitude for any DISTANCE activity, not just HIKING (Q-D6)", () => {
    const session = baseSession({
      activityType: "RUNNING",
      cardio: { distanceMeters: 5000, maxAltitudeMeters: 812.6 } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toContainEqual({ label: "cardioMaxAltitudeLabel", value: "813 m", icon: "landscape" });
  });

  it("shows a backpack tile only for HIKING, with a dash when unset", () => {
    const hike = baseSession({ activityType: "HIKING", cardio: { distanceMeters: 5000 } as WorkoutSessionResponse["cardio"] });
    expect(buildCardioTiles(hike, t, "en")).toContainEqual({ label: "cardioBackpackWeightLabel", value: "—", icon: "backpack" });

    const run = baseSession({ activityType: "RUNNING", cardio: { distanceMeters: 5000 } as WorkoutSessionResponse["cardio"] });
    expect(buildCardioTiles(run, t, "en").find((tile) => tile.icon === "backpack")).toBeUndefined();
  });

  it("shows the backpack weight formatted when set", () => {
    const session = baseSession({
      activityType: "HIKING",
      cardio: { distanceMeters: 5000, backpackWeightKg: 8.5 } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toContainEqual({ label: "cardioBackpackWeightLabel", value: "8.5 kg", icon: "backpack" });
  });

  it("shows GAP only when present, and only for HIKING — unlike backpack, no dash placeholder", () => {
    const hikeNoGap = baseSession({ activityType: "HIKING", cardio: { distanceMeters: 5000 } as WorkoutSessionResponse["cardio"] });
    expect(buildCardioTiles(hikeNoGap, t, "en").find((tile) => tile.icon === "trending_up")).toBeUndefined();

    const hikeWithGap = baseSession({
      activityType: "HIKING",
      cardio: { distanceMeters: 5000, avgGapSecondsPerKm: 323 } as WorkoutSessionResponse["cardio"],
    });
    expect(buildCardioTiles(hikeWithGap, t, "en")).toContainEqual({ label: "cardioGapLabel", value: "5:23 /km", icon: "trending_up" });

    const runWithGap = baseSession({
      activityType: "RUNNING",
      cardio: { distanceMeters: 5000, avgGapSecondsPerKm: 323 } as WorkoutSessionResponse["cardio"],
    });
    expect(buildCardioTiles(runWithGap, t, "en").find((tile) => tile.icon === "trending_up")).toBeUndefined();
  });
});

describe("buildCardioTiles — MACHINE family", () => {
  it("shows moving time, distance, cadence, resistance", () => {
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
      { label: "cardioAvgCadenceLabel", value: "82 rpm", icon: "autorenew" },
      { label: "cardioResistanceLabel", value: "6", icon: "tune" },
    ]);
  });

  it("never shows a standalone watts or machine-calories tile — those live in TotalWorkCard/CalorieCard instead", () => {
    const session = baseSession({
      activityType: "INDOOR_BIKE",
      cardio: { avgWatts: 164.3, deviceCalories: 421.9 } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles.find((tile) => tile.icon === "bolt")).toBeUndefined();
    expect(tiles.find((tile) => tile.icon === "local_fire_department")).toBeUndefined();
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

  it("adds venue and intensity when present", () => {
    const session = baseSession({
      activityType: "BASKETBALL",
      movingSeconds: 3120,
      cardio: { venue: "INDOOR", intensity: 4 } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toEqual([
      { label: "cardioPlayingTimeLabel", value: "52:00", icon: "schedule" },
      { label: "cardioVenueLabel", value: "cardioVenueIndoor", icon: "place" },
      { label: "cardioIntensityLabel", value: "4/5", icon: "whatshot" },
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

  it("labels the score tile Points on basketball, all three box-score fields shown", () => {
    const session = baseSession({
      activityType: "BASKETBALL",
      cardio: { scorePoints: 18, scoreRebounds: 7, scoreAssists: 4 } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toContainEqual({ label: "cardioBoxScorePointsLabel", value: "18", icon: "scoreboard" });
    expect(tiles).toContainEqual({ label: "cardioBoxScoreReboundsLabel", value: "7", icon: "replay" });
    expect(tiles).toContainEqual({ label: "cardioBoxScoreAssistsLabel", value: "4", icon: "handshake" });
  });

  it("labels the score tile Goals on football (docs/cardio/60 §8 C9w.2: only basketball says Points)", () => {
    const session = baseSession({
      activityType: "FOOTBALL",
      cardio: { scorePoints: 2, scoreAssists: 1 } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toContainEqual({ label: "cardioBoxScoreGoalsLabel", value: "2", icon: "scoreboard" });
    expect(tiles).toContainEqual({ label: "cardioBoxScoreAssistsLabel", value: "1", icon: "handshake" });
    // No rebounds tile at all for football, not a zero — the field was never set.
    expect(tiles.find((tile) => tile.icon === "replay")).toBeUndefined();
  });

  it("shows a zero score, not an omitted tile — 0 is a real result, not missing data", () => {
    const session = baseSession({
      activityType: "BASKETBALL",
      cardio: { scorePoints: 0 } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toContainEqual({ label: "cardioBoxScorePointsLabel", value: "0", icon: "scoreboard" });
  });

  it("adds a format tile mapped from the known game_format codes", () => {
    const session = baseSession({
      activityType: "BASKETBALL",
      cardio: { gameFormat: "SMALL_SIDED" } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toContainEqual({ label: "cardioGameFormatLabel", value: "cardioGameFormatSmallSided", icon: "grid_view" });
  });

  it("falls back to the raw code for an unrecognized game_format, instead of mislabeling it", () => {
    const session = baseSession({
      activityType: "BASKETBALL",
      cardio: { gameFormat: "THREE_ON_THREE" } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toContainEqual({ label: "cardioGameFormatLabel", value: "THREE_ON_THREE", icon: "grid_view" });
  });

  it("omits the format tile when game_format is absent", () => {
    const session = baseSession({
      activityType: "BASKETBALL",
      cardio: { venue: "INDOOR" } as WorkoutSessionResponse["cardio"],
    });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles.find((tile) => tile.icon === "grid_view")).toBeUndefined();
  });
});

describe("buildCardioTiles — duration fallback", () => {
  it("uses the gross wall-clock span when movingSeconds is absent", () => {
    const session = baseSession({ activityType: "WALKING", movingSeconds: null, cardio: null });
    const tiles = buildCardioTiles(session, t, "en");
    // 10:00:00Z → 10:45:16Z = 2716s, same as the movingSeconds case above.
    expect(tiles).toEqual([{ label: "cardioDurationLabel", value: "45:16", icon: "schedule" }]);
  });

  it("shows an em-dash when neither movingSeconds nor finishedAt is available (still running)", () => {
    const session = baseSession({ activityType: "WALKING", movingSeconds: null, finishedAt: null, cardio: null });
    const tiles = buildCardioTiles(session, t, "en");
    expect(tiles).toEqual([{ label: "cardioDurationLabel", value: "—", icon: "schedule" }]);
  });
});

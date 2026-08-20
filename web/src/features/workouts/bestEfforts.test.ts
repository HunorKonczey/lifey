import { describe, it, expect } from "vitest";
import { buildBestEffortRows } from "./bestEfforts";
import type { CardioDetailsResponse } from "./types";

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

describe("buildBestEffortRows", () => {
  it("returns all three rows when all three are recorded, unmarked with no records set", () => {
    const rows = buildBestEffortRows(cardio({ best1kSeconds: 240, best5kSeconds: 1320, best10kSeconds: 2820 }));
    expect(rows).toEqual([
      { labelKey: "cardioBestEffort1kLabel", seconds: 240, pace: "4:00 /km", isRecord: false },
      { labelKey: "cardioBestEffort5kLabel", seconds: 1320, pace: "4:24 /km", isRecord: false },
      { labelKey: "cardioBestEffort10kLabel", seconds: 2820, pace: "4:42 /km", isRecord: false },
    ]);
  });

  it("omits a distance the session never reached — not zero, not a placeholder row", () => {
    // A 4 km run: 1 km exists, 5/10 km are structurally impossible, not missing.
    const rows = buildBestEffortRows(cardio({ best1kSeconds: 240 }));
    expect(rows).toEqual([{ labelKey: "cardioBestEffort1kLabel", seconds: 240, pace: "4:00 /km", isRecord: false }]);
  });

  it("returns an empty array when no best effort was recorded", () => {
    expect(buildBestEffortRows(cardio())).toEqual([]);
  });

  it("keeps the 1k/5k/10k order regardless of which are present", () => {
    const rows = buildBestEffortRows(cardio({ best10kSeconds: 2820, best1kSeconds: 240 }));
    expect(rows.map((r) => r.labelKey)).toEqual(["cardioBestEffort1kLabel", "cardioBestEffort10kLabel"]);
  });

  it("marks only the rows present in the records set", () => {
    const rows = buildBestEffortRows(
      cardio({ best1kSeconds: 240, best5kSeconds: 1320, best10kSeconds: 2820 }),
      new Set(["5k"]),
    );
    expect(rows.map((r) => r.isRecord)).toEqual([false, true, false]);
  });
});

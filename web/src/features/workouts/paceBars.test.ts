import { describe, it, expect } from "vitest";
import { buildPaceBars } from "./paceBars";
import type { CardioSplitResponse } from "./types";

function split(overrides: Partial<CardioSplitResponse> = {}): CardioSplitResponse {
  return {
    splitIndex: 0,
    splitType: "DISTANCE",
    distanceMeters: 1000,
    durationSeconds: 300,
    elevationDeltaM: null,
    avgHeartRate: null,
    avgWatts: null,
    intensity: null,
    ...overrides,
  };
}

describe("buildPaceBars", () => {
  it("sorts by splitIndex, same order CardioSplitsTable uses", () => {
    const bars = buildPaceBars([
      split({ splitIndex: 1, durationSeconds: 280 }),
      split({ splitIndex: 0, durationSeconds: 300 }),
    ]);
    expect(bars.map((b) => b.durationSeconds)).toEqual([300, 280]);
  });

  it("marks a sub-999m split as partial (mirrors mobile's `< 999` threshold)", () => {
    const bars = buildPaceBars([split({ distanceMeters: 998 }), split({ splitIndex: 1, distanceMeters: 1000 })]);
    expect(bars[0].partial).toBe(true);
    expect(bars[1].partial).toBe(false);
  });

  it("treats a null distance (an INTERVAL split) as partial rather than crashing", () => {
    const bars = buildPaceBars([split({ distanceMeters: null })]);
    expect(bars[0].partial).toBe(true);
  });

  it("formats the label as m:ss, matching the table's duration column", () => {
    const bars = buildPaceBars([split({ durationSeconds: 323 })]);
    expect(bars[0].label).toBe("5:23");
  });

  it("returns one bar per split, the same length CardioSplitsTable receives", () => {
    const splits = [split({ splitIndex: 0 }), split({ splitIndex: 1 }), split({ splitIndex: 2 })];
    expect(buildPaceBars(splits)).toHaveLength(splits.length);
  });
});

import { describe, it, expect } from "vitest";
import { activityFamilyOf, activityTypeIcon, activityTypeColor } from "./activityType";

describe("activityFamilyOf", () => {
  it("maps running/walking/hiking to DISTANCE", () => {
    expect(activityFamilyOf("RUNNING")).toBe("DISTANCE");
    expect(activityFamilyOf("WALKING")).toBe("DISTANCE");
    expect(activityFamilyOf("HIKING")).toBe("DISTANCE");
  });
  it("maps indoor bike to MACHINE", () => {
    expect(activityFamilyOf("INDOOR_BIKE")).toBe("MACHINE");
  });
  it("maps basketball/football/other to GAME", () => {
    expect(activityFamilyOf("BASKETBALL")).toBe("GAME");
    expect(activityFamilyOf("FOOTBALL")).toBe("GAME");
    expect(activityFamilyOf("OTHER_CARDIO")).toBe("GAME");
  });
});

describe("activityTypeIcon", () => {
  it("returns the design-mapped icon per code", () => {
    expect(activityTypeIcon("RUNNING")).toBe("directions_run");
    expect(activityTypeIcon("INDOOR_BIKE")).toBe("pedal_bike");
    expect(activityTypeIcon("STRENGTH")).toBe("fitness_center");
  });
  it("falls back to bolt for null/undefined/unknown", () => {
    expect(activityTypeIcon(null)).toBe("bolt");
    expect(activityTypeIcon(undefined)).toBe("bolt");
  });
});

describe("activityTypeColor", () => {
  it("returns a metric-token CSS variable per code", () => {
    expect(activityTypeColor("RUNNING")).toBe("var(--metric-kcal)");
    expect(activityTypeColor("HIKING")).toBe("var(--tertiary)");
    expect(activityTypeColor("STRENGTH")).toBe("var(--metric-weight)");
  });
  it("falls back to on-surface-variant for null/undefined/unknown", () => {
    expect(activityTypeColor(null)).toBe("var(--on-surface-variant)");
  });
});

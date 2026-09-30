import { describe, expect, it } from "vitest";
import { exerciseIcon, formatRest, muscleGroupColor } from "./exerciseUi";

describe("formatRest", () => {
  it("minutes and seconds", () => {
    expect(formatRest(120)).toBe("2:00");
    expect(formatRest(90)).toBe("1:30");
    expect(formatRest(45)).toBe("0:45");
    expect(formatRest(605)).toBe("10:05");
  });

  it("no own rest is null (the user's default applies)", () => {
    expect(formatRest(null)).toBeNull();
    expect(formatRest(undefined)).toBeNull();
  });
});

describe("muscleGroupColor / exerciseIcon", () => {
  it("groups share a metric colour; unknown and missing fall back to the neutral one", () => {
    expect(muscleGroupColor("CHEST")).toBe(muscleGroupColor("QUADS"));
    expect(muscleGroupColor(null)).toBe("var(--metric-weight)");
    expect(muscleGroupColor("NOPE")).toBe("var(--metric-weight)");
  });

  it("cardio runs, bodyweight is gymnastics, the rest lifts", () => {
    expect(exerciseIcon({ category: "CARDIO", equipment: null })).toBe("directions_run");
    expect(exerciseIcon({ category: "CHEST", equipment: "BODYWEIGHT" })).toBe("sports_gymnastics");
    expect(exerciseIcon({ category: "CHEST", equipment: "BARBELL" })).toBe("fitness_center");
  });
});

import { describe, it, expect } from "vitest";
import {
  formatDistanceKm, formatDuration, formatPace, formatElevationDelta, totalWorkKj,
  formatElevation, formatWeight, formatTemperature, formatWindSpeed, formatPrecipitation,
} from "./cardioFormat";

describe("formatDistanceKm", () => {
  it("formats with 2 decimals and a period for en", () => {
    expect(formatDistanceKm(8420, "en")).toBe("8.42 km");
  });
  it("formats with 2 decimals and a comma for hu", () => {
    expect(formatDistanceKm(8420, "hu")).toBe("8,42 km");
  });
});

describe("formatDuration", () => {
  it("formats under an hour as m:ss", () => {
    expect(formatDuration(5 * 60 + 16)).toBe("5:16");
    expect(formatDuration(45 * 60 + 16)).toBe("45:16");
  });
  it("formats an hour or more as h:mm:ss", () => {
    expect(formatDuration(65 * 60 + 12)).toBe("1:05:12");
  });
  it("zero-pads seconds and minutes (in the h:mm:ss form)", () => {
    expect(formatDuration(60 * 5 + 3)).toBe("5:03");
    expect(formatDuration(3600 + 3 * 60 + 9)).toBe("1:03:09");
  });
});

describe("formatPace", () => {
  it("computes minutes:seconds per km", () => {
    // 8420m in 45:16 (2716s) → ~5:23/km
    expect(formatPace(8420, 2716)).toBe("5:23 /km");
  });
  it("returns null for zero or negative distance (avoids divide-by-zero)", () => {
    expect(formatPace(0, 100)).toBeNull();
    expect(formatPace(-5, 100)).toBeNull();
  });
});

describe("formatElevationDelta", () => {
  it("signs a positive delta with a leading +", () => {
    expect(formatElevationDelta(42.4)).toBe("+42 m");
  });
  it("keeps the minus sign a negative delta already carries", () => {
    expect(formatElevationDelta(-12.2)).toBe("-12 m");
  });
  it("shows zero unsigned", () => {
    expect(formatElevationDelta(0)).toBe("0 m");
  });
});

// Parity port of `cardio_formatter_test.dart`'s "totalWorkKj" group
// (docs/cardio/60 §8 C7w.2 kész-ha) — same input/output pairs.
describe("totalWorkKj", () => {
  it("is average power over the time it was held", () => {
    // 168 W for 30:00 = 302.4 kJ.
    expect(totalWorkKj(168, 1800)).toBe(302);
  });

  it("is null without power — the number it would print is not a zero", () => {
    expect(totalWorkKj(null, 1800)).toBeNull();
    expect(totalWorkKj(0, 1800)).toBeNull();
  });

  it("is null without a moving time to hold that power over", () => {
    expect(totalWorkKj(168, null)).toBeNull();
    expect(totalWorkKj(168, 0)).toBeNull();
  });

  it("follows a corrected average, since nothing stores the result", () => {
    // Same 30:00, average corrected from 168 to 200 → 360, not the original 302.
    expect(totalWorkKj(200, 1800)).toBe(360);
  });
});

describe("formatElevation", () => {
  it("rounds to whole meters", () => {
    expect(formatElevation(1234.6)).toBe("1235 m");
  });
});

describe("formatWeight", () => {
  it("keeps one decimal", () => {
    expect(formatWeight(8.5)).toBe("8.5 kg");
    expect(formatWeight(9)).toBe("9.0 kg");
  });
});

describe("formatTemperature", () => {
  it("rounds to whole degrees and keeps the sign", () => {
    expect(formatTemperature(7.4)).toBe("7 °C");
    expect(formatTemperature(-3.6)).toBe("-4 °C");
  });
});

describe("formatWindSpeed", () => {
  it("rounds to whole km/h", () => {
    expect(formatWindSpeed(11.6)).toBe("12 km/h");
  });
});

describe("formatPrecipitation", () => {
  it("rounds to whole mm", () => {
    expect(formatPrecipitation(0.4)).toBe("0 mm");
  });
});

import { describe, it, expect } from "vitest";
import { formatDistanceKm, formatDuration, formatPace } from "./cardioFormat";

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

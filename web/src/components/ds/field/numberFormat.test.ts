import { describe, expect, it } from "vitest";
import { clampNumber, formatLocaleNumber, parseLocaleNumber, roundToDecimals } from "./numberFormat";

describe("parseLocaleNumber", () => {
  it("parses the Hungarian comma decimal", () => {
    expect(parseLocaleNumber("166,7", "hu")).toBe(166.7);
  });

  it("parses the English dot decimal", () => {
    expect(parseLocaleNumber("166.7", "en")).toBe(166.7);
  });

  it("is null for empty input or a bare minus, not NaN", () => {
    expect(parseLocaleNumber("", "en")).toBeNull();
    expect(parseLocaleNumber("   ", "en")).toBeNull();
    expect(parseLocaleNumber("-", "en")).toBeNull();
  });

  it("is null for garbage", () => {
    expect(parseLocaleNumber("abc", "en")).toBeNull();
  });

  it("parses negatives and whole numbers", () => {
    expect(parseLocaleNumber("-3", "en")).toBe(-3);
    expect(parseLocaleNumber("68", "hu")).toBe(68);
  });
});

describe("formatLocaleNumber", () => {
  it("uses the locale's decimal separator, no grouping", () => {
    expect(formatLocaleNumber(166.7, "hu", 1)).toBe("166,7");
    expect(formatLocaleNumber(166.7, "en", 1)).toBe("166.7");
    expect(formatLocaleNumber(1739, "hu", 1)).toBe("1739");
  });

  it("drops a trailing zero decimal for a whole number", () => {
    expect(formatLocaleNumber(68, "en", 1)).toBe("68");
  });

  it("rounds to the max decimals", () => {
    expect(formatLocaleNumber(166.68, "en", 1)).toBe("166.7");
  });
});

describe("clampNumber", () => {
  it("clamps to min and max", () => {
    expect(clampNumber(5, 0, 10)).toBe(5);
    expect(clampNumber(-5, 0, 10)).toBe(0);
    expect(clampNumber(15, 0, 10)).toBe(10);
  });

  it("is a no-op with no bounds", () => {
    expect(clampNumber(42)).toBe(42);
  });
});

describe("roundToDecimals", () => {
  it("rounds like the canvas example 166.68 -> 166.7", () => {
    expect(roundToDecimals(166.68, 1)).toBe(166.7);
  });

  it("rounds to a whole number at 0 decimals", () => {
    expect(roundToDecimals(166.68, 0)).toBe(167);
  });
});

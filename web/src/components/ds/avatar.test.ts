import { describe, expect, it } from "vitest";
import { colorForSeed, initialsFor } from "./Avatar";

describe("initialsFor", () => {
  it("takes the first and last word's initial", () => {
    expect(initialsFor("Anna Kovács")).toBe("AK");
    expect(initialsFor("Nagy Kata Réka")).toBe("NR");
  });

  it("takes a single word's initial", () => {
    expect(initialsFor("Anna")).toBe("A");
  });

  it("falls back to the e-mail's first letter with no name", () => {
    expect(initialsFor(null, "anna.kovacs@example.com")).toBe("A");
    expect(initialsFor("", "anna.kovacs@example.com")).toBe("A");
  });

  it("is '?' with neither a name nor an e-mail", () => {
    expect(initialsFor(null, null)).toBe("?");
    expect(initialsFor("  ", "")).toBe("?");
  });

  it("uppercases and handles accented letters as whole characters", () => {
    expect(initialsFor("örs kovács")).toBe("ÖK");
  });
});

describe("colorForSeed", () => {
  it("is stable for the same seed", () => {
    expect(colorForSeed("user-42")).toBe(colorForSeed("user-42"));
  });

  it("returns one of the metric colour variables", () => {
    const result = colorForSeed("anna.kovacs@example.com");
    expect(result).toMatch(/^var\(--m-(water|steps|fat|carbs|kcal|weight)\)$/);
  });

  it("usually differs for different seeds (not a constant)", () => {
    const colors = new Set(["a", "b", "c", "d", "e", "f", "g"].map(colorForSeed));
    expect(colors.size).toBeGreaterThan(1);
  });
});

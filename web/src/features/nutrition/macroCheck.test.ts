import { describe, expect, it } from "vitest";
import { macroCheck } from "./macroCheck";

describe("macroCheck", () => {
  it("is ok when 4P + 4C + 9F matches the kcal", () => {
    // oats: 13 P, 60 C, 7 F -> 52 + 240 + 63 = 355
    expect(macroCheck({ kcal: 355, protein: 13, carbs: 60, fat: 7 })).toEqual({ computedKcal: 355, diffKcal: 0, tone: "ok" });
  });

  it("compares the rounded figures — 354.6 kcal against macros that give 355 is still ok", () => {
    expect(macroCheck({ kcal: 354.6, protein: 13, carbs: 60, fat: 7 }).tone).toBe("ok");
  });

  it("is an info line for a small difference (canvas: macros give 72, stated 73 -> 1 off)", () => {
    // 4·5 + 4·8 + 9·2.2 = 71.8 -> 72
    const check = macroCheck({ kcal: 73, protein: 5, carbs: 8, fat: 2.2 });
    expect(check.computedKcal).toBe(72);
    expect(check.diffKcal).toBe(1);
    expect(check.tone).toBe("info");
  });

  it("is an info line up to and including 10 % off, a warning above it", () => {
    // stated 100: macros give 110 -> exactly 10 % -> info; 111 -> 11 % -> warning
    expect(macroCheck({ kcal: 100, protein: 0, carbs: 0, fat: 110 / 9 }).tone).toBe("info");
    expect(macroCheck({ kcal: 100, protein: 0, carbs: 0, fat: 111 / 9 }).tone).toBe("warning");
  });

  it("measures the share against the stated kcal in both directions", () => {
    // stated 200, macros give 170 (15 % under) -> warning
    expect(macroCheck({ kcal: 200, protein: 0, carbs: 42.5, fat: 0 }).tone).toBe("warning");
  });

  it("is a warning when kcal is 0 but the macros are not", () => {
    expect(macroCheck({ kcal: 0, protein: 10, carbs: 0, fat: 0 })).toEqual({ computedKcal: 40, diffKcal: 40, tone: "warning" });
  });

  it("is ok for an all-zero food (water)", () => {
    expect(macroCheck({ kcal: 0, protein: 0, carbs: 0, fat: 0 }).tone).toBe("ok");
  });
});

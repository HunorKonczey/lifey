import { describe, expect, it } from "vitest";
import { dominantMacro, recipeTint } from "./recipeTint";

describe("dominantMacro", () => {
  it("is the macro with the biggest kcal share, not the most grams", () => {
    // 30 g protein = 120 kcal, 40 g carbs = 160 kcal, 20 g fat = 180 kcal -> fat, though it is the fewest grams
    expect(dominantMacro({ protein: 30, carbs: 40, fat: 20 })).toBe("fat");
    // 38 P = 152, 58 C = 232, 14 F = 126 (the canvas' rice bowl) -> carbs
    expect(dominantMacro({ protein: 38, carbs: 58, fat: 14 })).toBe("carbs");
    expect(dominantMacro({ protein: 46, carbs: 0, fat: 5 })).toBe("protein");
  });

  it("breaks a tie toward protein, then carbs", () => {
    expect(dominantMacro({ protein: 10, carbs: 10, fat: 0 })).toBe("protein");
    expect(dominantMacro({ protein: 0, carbs: 9, fat: 4 })).toBe("carbs"); // 36 vs 36
  });

  it("has none when there is nothing to go on", () => {
    expect(dominantMacro({ protein: 0, carbs: 0, fat: 0 })).toBeNull();
  });
});

describe("recipeTint", () => {
  it("maps the dominant macro to its metric colour", () => {
    expect(recipeTint({ protein: 50, carbs: 5, fat: 2 }).color).toBe("var(--metric-protein)");
    expect(recipeTint({ protein: 5, carbs: 50, fat: 2 }).color).toBe("var(--metric-carbs)");
    expect(recipeTint({ protein: 5, carbs: 5, fat: 30 }).color).toBe("var(--metric-fat)");
  });

  it("falls back to a neutral book icon", () => {
    expect(recipeTint({ protein: 0, carbs: 0, fat: 0 })).toEqual({ macro: "none", color: "var(--primary)", icon: "menu_book" });
  });
});

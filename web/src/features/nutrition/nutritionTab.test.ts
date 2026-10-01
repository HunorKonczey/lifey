import { describe, expect, it } from "vitest";
import { nutritionTabHref, parseNutritionTab } from "./nutritionTab";

describe("parseNutritionTab", () => {
  it("accepts the three tabs", () => {
    expect(parseNutritionTab("meals")).toBe("meals");
    expect(parseNutritionTab("foods")).toBe("foods");
    expect(parseNutritionTab("recipes")).toBe("recipes");
  });

  it("falls back to meals for missing, empty or unknown values", () => {
    expect(parseNutritionTab(null)).toBe("meals");
    expect(parseNutritionTab(undefined)).toBe("meals");
    expect(parseNutritionTab("")).toBe("meals");
    expect(parseNutritionTab("Foods")).toBe("meals"); // case-sensitive: only the canonical values
    expect(parseNutritionTab("workouts")).toBe("meals");
  });
});

describe("nutritionTabHref", () => {
  it("meals is the bare route; the others carry ?tab=", () => {
    expect(nutritionTabHref("meals")).toBe("/nutrition");
    expect(nutritionTabHref("foods")).toBe("/nutrition?tab=foods");
    expect(nutritionTabHref("recipes")).toBe("/nutrition?tab=recipes");
  });

  it("round-trips through parseNutritionTab", () => {
    for (const tab of ["meals", "foods", "recipes"] as const) {
      const href = nutritionTabHref(tab);
      const q = new URL(href, "http://x").searchParams.get("tab");
      expect(parseNutritionTab(q)).toBe(tab);
    }
  });
});

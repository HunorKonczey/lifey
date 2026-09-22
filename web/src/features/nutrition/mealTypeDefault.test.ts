import { describe, it, expect } from "vitest";
import { defaultMealType } from "./mealTypeDefault";

const at = (hour: number, minute = 0) => new Date(2026, 8, 22, hour, minute);

describe("defaultMealType", () => {
  it.each([
    [0, "BREAKFAST"],
    [10, "BREAKFAST"],
    [11, "LUNCH"],
    [14, "LUNCH"],
    [15, "DINNER"],
    [20, "DINNER"],
    [21, "SNACK"],
    [23, "SNACK"],
  ])("hour %i → %s", (hour, expected) => {
    expect(defaultMealType(at(hour, 30))).toBe(expected);
  });
});

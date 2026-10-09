import { describe, expect, it } from "vitest";
import { quantityChips } from "./quantityChips";

describe("quantityChips", () => {
  it("a food without servings: 100 g, plus the last used amount when it differs", () => {
    expect(quantityChips({ recipe: false })).toEqual([{ value: 100 }]);
    expect(quantityChips({ recipe: false, lastGrams: 150.4 })).toEqual([{ value: 100 }, { value: 150 }]);
    expect(quantityChips({ recipe: false, lastGrams: 100.2 })).toEqual([{ value: 100 }]);
  });

  it("a food's servings come first, in order, then the plain amounts", () => {
    const chips = quantityChips({
      recipe: false,
      servings: [{ name: "1 glass", grams: 200 }, { name: "1 spoon", grams: 15 }],
      lastGrams: 150,
    });

    expect(chips).toEqual([{ value: 200, serving: "1 glass" }, { value: 15, serving: "1 spoon" }, { value: 100 }, { value: 150 }]);
  });

  it("a plain amount a serving already names is not offered twice", () => {
    expect(quantityChips({ recipe: false, servings: [{ name: "1 slice", grams: 100 }], lastGrams: 100 })).toEqual([
      { value: 100, serving: "1 slice" },
    ]);
    expect(quantityChips({ recipe: false, servings: [{ name: "1 bowl", grams: 150 }], lastGrams: 150 })).toEqual([
      { value: 150, serving: "1 bowl" },
      { value: 100 },
    ]);
  });

  it("a recipe offers half, one and two servings of itself, whatever else is given", () => {
    expect(quantityChips({ recipe: true, servings: [{ name: "x", grams: 5 }], lastGrams: 3 })).toEqual([{ value: 0.5 }, { value: 1 }, { value: 2 }]);
  });
});

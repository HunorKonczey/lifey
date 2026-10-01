import { describe, expect, it } from "vitest";
import { editedEntries, isMealDirty, round1 } from "./mealEdit";
import type { MealEntryResponse } from "./types";

const entry = (foodId: number, quantityInGrams: number): MealEntryResponse => ({
  foodId,
  foodName: `f${foodId}`,
  quantityInGrams,
  calories: 100,
  protein: 10,
  carbs: 10,
  fat: 1,
});

const entries = [entry(1, 60), entry(2, 166.68518), entry(3, 80)];

describe("round1", () => {
  it("rounds to one decimal, the way the field shows a quantity", () => {
    expect(round1(166.68518)).toBe(166.7);
    expect(round1(135.04)).toBe(135);
  });
});

describe("isMealDirty", () => {
  it("nothing touched is clean", () => {
    expect(isMealDirty(entries, [null, null, null])).toBe(false);
  });

  it("a changed quantity is dirty", () => {
    expect(isMealDirty(entries, [null, null, 85])).toBe(true);
  });

  it("typing back what the drawer showed is not a change — 166,7 against a stored 166.685…", () => {
    expect(isMealDirty(entries, [null, 166.7, null])).toBe(false);
    expect(isMealDirty(entries, [60, null, null])).toBe(false);
  });

  it("editing away and back ends clean again", () => {
    expect(isMealDirty(entries, [null, 170, null])).toBe(true);
    expect(isMealDirty(entries, [null, 166.7, null])).toBe(false);
  });
});

describe("editedEntries", () => {
  it("edited rows take their new quantity", () => {
    expect(editedEntries(entries, [null, null, 85]).map((e) => e.quantityInGrams)).toEqual([60, 166.68518, 85]);
  });

  it("untouched rows keep the stored, unrounded quantity — never a rounded copy", () => {
    const out = editedEntries(entries, [70, null, null]);
    expect(out[1].quantityInGrams).toBe(166.68518);
  });

  it("a row edited back to what was shown keeps the exact stored value", () => {
    expect(editedEntries(entries, [null, 166.7, null])[1].quantityInGrams).toBe(166.68518);
  });

  it("carries the food ids through in order", () => {
    expect(editedEntries(entries, [null, null, null]).map((e) => e.foodId)).toEqual([1, 2, 3]);
  });
});

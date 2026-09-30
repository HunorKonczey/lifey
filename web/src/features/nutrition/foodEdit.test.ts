import { describe, expect, it } from "vitest";
import { duplicateName, EMPTY_FOOD, fieldsFromFood, foodRequest, isFoodDirty } from "./foodEdit";
import type { FoodResponse } from "./types";

const FOOD: FoodResponse = {
  id: 7,
  name: "Zabpehely",
  caloriesPer100g: 372.123,
  proteinPer100g: 13.3333,
  carbsPer100g: 58.7,
  fatPer100g: null,
  barcode: null,
  hidden: false,
};

describe("fieldsFromFood", () => {
  it("keeps stored numbers unrounded and turns nulls into 0 / empty", () => {
    expect(fieldsFromFood(FOOD)).toEqual({ name: "Zabpehely", kcal: 372.123, protein: 13.3333, carbs: 58.7, fat: 0, barcode: "" });
  });

  it("starts from a prefill (barcode lookup) and from nothing", () => {
    expect(fieldsFromFood(null, { name: "Joghurt", caloriesPer100g: 61, barcode: "5990" }).barcode).toBe("5990");
    expect(fieldsFromFood(null)).toEqual(EMPTY_FOOD);
  });
});

describe("isFoodDirty", () => {
  const original = fieldsFromFood(FOOD);

  it("is clean when nothing changed, even if a field re-committed its number at two decimals", () => {
    expect(isFoodDirty(original, original)).toBe(false);
    expect(isFoodDirty({ ...original, protein: 13.33, kcal: 372.12 }, original)).toBe(false);
  });

  it("is dirty for a real change in any field", () => {
    expect(isFoodDirty({ ...original, name: "Zab" }, original)).toBe(true);
    expect(isFoodDirty({ ...original, protein: 13.4 }, original)).toBe(true);
    expect(isFoodDirty({ ...original, fat: 2 }, original)).toBe(true);
    expect(isFoodDirty({ ...original, barcode: "123" }, original)).toBe(true);
  });

  it("ignores whitespace around the name", () => {
    expect(isFoodDirty({ ...original, name: "  Zabpehely " }, original)).toBe(false);
  });
});

describe("foodRequest", () => {
  const original = fieldsFromFood(FOOD);

  it("sends untouched numbers exactly as stored and edited ones as typed", () => {
    const req = foodRequest({ ...original, protein: 13.33, carbs: 60 }, original, false);
    expect(req.proteinPer100g).toBe(13.3333); // re-committed at two decimals, not a change
    expect(req.caloriesPer100g).toBe(372.123);
    expect(req.carbsPer100g).toBe(60);
  });

  it("trims the name, turns an empty barcode into null and carries `hidden` over", () => {
    const req = foodRequest({ ...original, name: " Zab ", barcode: "  " }, original, true);
    expect(req).toMatchObject({ name: "Zab", barcode: null, hidden: true });
  });

  it("works for a new food (original = empty)", () => {
    expect(foodRequest({ name: "Tojás", kcal: 143, protein: 12.6, carbs: 0.7, fat: 9.5, barcode: "" }, EMPTY_FOOD, false)).toEqual({
      name: "Tojás",
      caloriesPer100g: 143,
      proteinPer100g: 12.6,
      carbsPer100g: 0.7,
      fatPer100g: 9.5,
      barcode: null,
      hidden: false,
    });
  });
});

describe("duplicateName", () => {
  it("appends the copy word, then a counter while the name is taken (case-insensitive)", () => {
    expect(duplicateName("Oats", ["Oats"], "copy")).toBe("Oats (copy)");
    expect(duplicateName("Oats", ["Oats", "oats (COPY)"], "copy")).toBe("Oats (copy 2)");
    expect(duplicateName("Oats", ["Oats", "Oats (copy)", "Oats (copy 2)"], "copy")).toBe("Oats (copy 3)");
  });
});

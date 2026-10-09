import { describe, expect, it } from "vitest";
import { duplicateName, EMPTY_FOOD, fieldsFromFood, foodRequest, gramsText, isFoodDirty, parseOptionalGrams } from "./foodEdit";
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
    expect(fieldsFromFood(FOOD)).toEqual({ name: "Zabpehely", kcal: 372.123, protein: 13.3333, carbs: 58.7, fat: 0, fiber: "", sugar: "", barcode: "" });
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
    expect(foodRequest({ name: "Tojás", kcal: 143, protein: 12.6, carbs: 0.7, fat: 9.5, fiber: "", sugar: "", barcode: "" }, EMPTY_FOOD, false)).toEqual({
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

describe("fibre and sugar (LIF-145)", () => {
  const original = fieldsFromFood(FOOD);

  it("parseOptionalGrams: empty is not known, a comma or a point is a decimal, anything else is invalid", () => {
    expect(parseOptionalGrams("")).toBeNull();
    expect(parseOptionalGrams("   ")).toBeNull();
    expect(parseOptionalGrams("8,5")).toBe(8.5);
    expect(parseOptionalGrams("8.5")).toBe(8.5);
    expect(parseOptionalGrams("0")).toBe(0);
    expect(parseOptionalGrams("100")).toBe(100);
    expect(parseOptionalGrams("100.5")).toBe("invalid");
    expect(parseOptionalGrams("-1")).toBe("invalid");
    expect(parseOptionalGrams("abc")).toBe("invalid");
    expect(parseOptionalGrams("1,2,3")).toBe("invalid");
  });

  it("a stored figure round-trips as text; an unknown one is empty, and 0 stays 0", () => {
    expect(gramsText(null)).toBe("");
    expect(gramsText(undefined)).toBe("");
    expect(gramsText(0)).toBe("0");
    expect(gramsText(8.456)).toBe("8.46");
    expect(fieldsFromFood({ ...FOOD, fiberPer100g: 10, sugarPer100g: 0 })).toMatchObject({ fiber: "10", sugar: "0" });
  });

  it("the request carries a known figure and leaves an unknown one out (it is not 0)", () => {
    expect(foodRequest({ ...original, fiber: "10", sugar: "" }, original, false)).toMatchObject({ fiberPer100g: 10 });
    const none = foodRequest(original, original, false);
    expect(none).not.toHaveProperty("fiberPer100g");
    expect(none).not.toHaveProperty("sugarPer100g");
    expect(foodRequest({ ...original, sugar: "0" }, original, false).sugarPer100g).toBe(0);
  });

  it("an edit that only touches fibre or sugar is a change; clearing a stored one is too", () => {
    expect(isFoodDirty({ ...original, fiber: "3" }, original)).toBe(true);
    const stored = fieldsFromFood({ ...FOOD, fiberPer100g: 10 });
    expect(isFoodDirty(stored, stored)).toBe(false);
    expect(isFoodDirty({ ...stored, fiber: "" }, stored)).toBe(true);
  });
});

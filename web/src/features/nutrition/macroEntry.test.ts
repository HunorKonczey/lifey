import { describe, expect, it } from "vitest";
import { EMPTY_MACRO_DRAFT, parseMacroDraft, per100g } from "./macroEntry";

const draft = (over: Partial<typeof EMPTY_MACRO_DRAFT>) => ({ ...EMPTY_MACRO_DRAFT, ...over });

describe("parseMacroDraft", () => {
  it("needs calories", () => {
    expect(parseMacroDraft(EMPTY_MACRO_DRAFT, "en")).toBeNull();
    expect(parseMacroDraft(draft({ protein: "20" }), "en")).toBeNull();
  });

  it("defaults the rest: 100 g, no protein / carbs / fat", () => {
    expect(parseMacroDraft(draft({ calories: "250" }), "en")).toEqual({
      name: "",
      grams: 100,
      totals: { calories: 250, protein: 0, carbs: 0, fat: 0 },
    });
  });

  it("reads the locale's decimal separator and trims the name", () => {
    const hu = parseMacroDraft(draft({ name: "  Lecsó ", calories: "312,5", protein: "11,2", carbs: "20", fat: "4", grams: "250" }), "hu");
    expect(hu).toEqual({ name: "Lecsó", grams: 250, totals: { calories: 312.5, protein: 11.2, carbs: 20, fat: 4 } });
  });

  it("blocks text and negative numbers instead of guessing", () => {
    expect(parseMacroDraft(draft({ calories: "abc" }), "en")).toBeNull();
    expect(parseMacroDraft(draft({ calories: "100", protein: "-3" }), "en")).toBeNull();
    expect(parseMacroDraft(draft({ calories: "100", fat: "x" }), "en")).toBeNull();
  });

  it("never goes below 1 g", () => {
    expect(parseMacroDraft(draft({ calories: "10", grams: "0" }), "en")?.grams).toBe(1);
  });
});

describe("per100g", () => {
  it("round-trips: per 100 g × grams / 100 = the typed totals", () => {
    const totals = { calories: 300, protein: 30, carbs: 15, fat: 6 };
    const p = per100g(totals, 250);
    expect(p.calories).toBeCloseTo(120);
    expect(p.protein).toBeCloseTo(12);
    expect(p.carbs).toBeCloseTo(6);
    expect(p.fat).toBeCloseTo(2.4);
    expect((p.calories * 250) / 100).toBeCloseTo(300);
  });
});

import { describe, expect, it } from "vitest";
import {
  OFF_SEARCH_MIN_LENGTH,
  isOffSearchable,
  offItemToSearchItem,
  offSearchEnabled,
  offSearchLang,
  sanitizeOffQuery,
} from "./offSearch";
import type { OffSearchItem } from "./types";

// The same cases as the backend's OffSearchQueryTest: the two sides must clean text alike (docs/84 D11).
describe("sanitizeOffQuery — parity with the backend's OffSearchQuery.sanitize", () => {
  it("keeps accents and lower-cases", () => {
    expect(sanitizeOffQuery("Túró Rudi")).toBe("túró rudi");
    expect(sanitizeOffQuery("Sütőtök")).toBe("sütőtök");
  });

  it("drops search-syntax characters", () => {
    expect(sanitizeOffQuery("tej:")).toBe("tej");
    expect(sanitizeOffQuery('categories_tags:"en:beverages" tej')).toBe("categories tags en beverages tej");
    expect(sanitizeOffQuery('"tej')).toBe("tej");
    expect(sanitizeOffQuery("tej*")).toBe("tej");
    expect(sanitizeOffQuery("(tej OR sajt) ~2 ^3")).toBe("tej or sajt 2 3");
  });

  it("lower-casing defuses upper-case operators", () => {
    expect(sanitizeOffQuery("a OR")).toBe("a or");
    expect(sanitizeOffQuery("tej AND NOT sajt")).toBe("tej and not sajt");
  });

  it("keeps a hyphen or apostrophe inside a word, drops one that would mean NOT", () => {
    expect(sanitizeOffQuery("coca-cola")).toBe("coca-cola");
    expect(sanitizeOffQuery("lay's")).toBe("lay's");
    expect(sanitizeOffQuery("-tej")).toBe("tej");
    expect(sanitizeOffQuery("tej -sajt")).toBe("tej sajt");
    expect(sanitizeOffQuery("tej - sajt")).toBe("tej sajt");
    expect(sanitizeOffQuery("tej-")).toBe("tej");
  });

  it("collapses and trims spaces", () => {
    expect(sanitizeOffQuery("   görög    joghurt \t")).toBe("görög joghurt");
  });

  it("gives an empty string when nothing searchable is left", () => {
    expect(sanitizeOffQuery("")).toBe("");
    expect(sanitizeOffQuery("   ")).toBe("");
    expect(sanitizeOffQuery(':"*()-')).toBe("");
  });
});

describe("isOffSearchable — the 3 letters or digits rule (FoodController)", () => {
  it("is exactly 3 letters or digits", () => {
    expect(OFF_SEARCH_MIN_LENGTH).toBe(3);
    expect(isOffSearchable("tej")).toBe(true);
    expect(isOffSearchable("túró")).toBe(true);
    expect(isOffSearchable("a1b")).toBe(true);
    expect(isOffSearchable("123")).toBe(true);
  });

  it("is not met by fewer, nor by spaces, hyphens or punctuation making up the length", () => {
    expect(isOffSearchable("")).toBe(false);
    expect(isOffSearchable("ab")).toBe(false);
    expect(isOffSearchable("a b")).toBe(false);
    expect(isOffSearchable("  ab  ")).toBe(false);
    expect(isOffSearchable("a-b")).toBe(false);
    expect(isOffSearchable(":::")).toBe(false);
    expect(isOffSearchable('"a"')).toBe(false);
    expect(isOffSearchable("ab:*")).toBe(false);
  });

  it("judges the cleaned text, so what the backend would reject is never sent", () => {
    // 5 characters typed, but the colon is cleaned away and two letters are left.
    expect(isOffSearchable("a:b::")).toBe(false);
    expect(isOffSearchable("a:b:c")).toBe(true); // → "a b c": three letters
  });
});

describe("offSearchEnabled — a request is made only when…", () => {
  it("the option is ticked and both the typed and the settled text are searchable", () => {
    expect(offSearchEnabled(true, "tej", "tej")).toBe(true);
    expect(offSearchEnabled(true, "tejföl", "tej")).toBe(true); // typing on: the older settled text still shows
  });

  it("the option is off: never", () => {
    expect(offSearchEnabled(false, "tej", "tej")).toBe(false);
  });

  it("what is typed is too short, even if the debounced text still is not (deleting letters stops it at once)", () => {
    expect(offSearchEnabled(true, "te", "tej")).toBe(false);
    expect(offSearchEnabled(true, "", "tej")).toBe(false);
  });

  it("the typing has not settled into something searchable yet", () => {
    expect(offSearchEnabled(true, "tej", "te")).toBe(false);
    expect(offSearchEnabled(true, "tej", "")).toBe(false);
  });
});

describe("offSearchLang", () => {
  it("Hungarian locales search Hungarian", () => {
    expect(offSearchLang("hu")).toBe("hu");
    expect(offSearchLang("hu-HU")).toBe("hu");
    expect(offSearchLang("HU")).toBe("hu");
  });

  it("everything else searches English", () => {
    expect(offSearchLang("en")).toBe("en");
    expect(offSearchLang("en-US")).toBe("en");
    expect(offSearchLang("de")).toBe("en");
  });
});

describe("offItemToSearchItem", () => {
  const item: OffSearchItem = {
    barcode: "4056489827702",
    name: "Csirkemell",
    brand: "Pikok",
    caloriesPer100g: 110,
    proteinPer100g: 14,
    carbsPer100g: 2.4,
    fatPer100g: 4.9,
  };

  it("is a row keyed by the barcode, carrying the whole result", () => {
    const row = offItemToSearchItem(item);

    expect(row.kind).toBe("off");
    expect(row.key).toBe("off:4056489827702");
    expect(row.name).toBe("Csirkemell");
    expect(row.off).toBe(item);
  });

  it("keeps missing carbs, fat and brand as null — nothing is invented", () => {
    const row = offItemToSearchItem({ ...item, brand: null, carbsPer100g: null, fatPer100g: null });

    expect(row.off.brand).toBeNull();
    expect(row.off.carbsPer100g).toBeNull();
    expect(row.off.fatPer100g).toBeNull();
  });

  it("can not collide with an own food or recipe row key", () => {
    expect(offItemToSearchItem(item).key).not.toMatch(/^(food|recipe):/);
  });
});

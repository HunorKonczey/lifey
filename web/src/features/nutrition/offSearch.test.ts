import { describe, expect, it } from "vitest";
import {
  OFF_SEARCH_MIN_LENGTH,
  OFF_SEARCH_PREF_KEY,
  isOffSearchable,
  offItemToSearchItem,
  offPortion,
  offSearchEnabled,
  offSearchLang,
  offSearchNote,
  readOffSearchPreference,
  sanitizeOffQuery,
  writeOffSearchPreference,
} from "./offSearch";
import type { OffSearchItem, OffSearchResponse } from "./types";

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

describe("offPortion", () => {
  it("scales per-100 g values to the grams, a missing carbs or fat counting as 0", () => {
    const item: OffSearchItem = { barcode: "1", name: "X", brand: null, caloriesPer100g: 110, proteinPer100g: 14, carbsPer100g: null, fatPer100g: 4.9 };

    const p = offPortion(item, 150);
    expect(p.calories).toBeCloseTo(165);
    expect(p.protein).toBeCloseTo(21);
    expect(p.carbs).toBe(0);
    expect(p.fat).toBeCloseTo(7.35);
    expect(offPortion(item, 0)).toEqual({ calories: 0, protein: 0, carbs: 0, fat: 0 });
  });
});

describe("offSearchNote — the one line under the OpenFoodFacts rows", () => {
  const ok = (over: Partial<OffSearchResponse> = {}): OffSearchResponse => ({
    status: "OK", language: "hu", fellBackToEnglish: false, items: [], ...over,
  });

  it("is none for a plain answer, and before there is one", () => {
    expect(offSearchNote(ok(), false)).toBeNull();
    expect(offSearchNote(undefined, false)).toBeNull();
  });

  it("names the English fallback", () => {
    expect(offSearchNote(ok({ language: "en", fellBackToEnglish: true }), false)).toBe("fellBack");
  });

  it("says unavailable or rate-limited for those statuses", () => {
    expect(offSearchNote(ok({ status: "UNAVAILABLE" }), false)).toBe("unavailable");
    expect(offSearchNote(ok({ status: "RATE_LIMITED" }), false)).toBe("rateLimited");
  });

  it("reads a failed request as unavailable, whatever an older answer said", () => {
    expect(offSearchNote(undefined, true)).toBe("unavailable");
    expect(offSearchNote(ok({ language: "en", fellBackToEnglish: true }), true)).toBe("unavailable");
  });
});

describe("the remembered checkbox", () => {
  const memory = () => {
    const data = new Map<string, string>();
    return { getItem: (k: string) => data.get(k) ?? null, setItem: (k: string, v: string) => void data.set(k, v), data };
  };
  const broken = {
    getItem: () => { throw new Error("blocked"); },
    setItem: () => { throw new Error("blocked"); },
  };

  it("is off until ticked", () => {
    expect(readOffSearchPreference(memory())).toBe(false);
  });

  it("remembers on and off", () => {
    const m = memory();
    writeOffSearchPreference(true, m);
    expect(m.data.get(OFF_SEARCH_PREF_KEY)).toBe("1");
    expect(readOffSearchPreference(m)).toBe(true);
    writeOffSearchPreference(false, m);
    expect(readOffSearchPreference(m)).toBe(false);
  });

  it("treats anything but 1 as off", () => {
    const m = memory();
    m.setItem(OFF_SEARCH_PREF_KEY, "true");
    expect(readOffSearchPreference(m)).toBe(false);
  });

  it("never throws when storage is missing or blocked", () => {
    expect(readOffSearchPreference(undefined)).toBe(false);
    expect(() => writeOffSearchPreference(true, undefined)).not.toThrow();
    expect(readOffSearchPreference(broken)).toBe(false);
    expect(() => writeOffSearchPreference(true, broken)).not.toThrow();
  });
});

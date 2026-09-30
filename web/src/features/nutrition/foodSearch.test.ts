import { describe, expect, it } from "vitest";
import { buildSearchItems, searchItems, usageByKey, type ItemUsage, type SearchFilter } from "./foodSearch";
import type { FoodResponse, RecipeResponse } from "./types";

const food = (id: number, name: string, over: Partial<FoodResponse> = {}): FoodResponse => ({
  id,
  name,
  caloriesPer100g: 100,
  proteinPer100g: 5,
  carbsPer100g: 10,
  fatPer100g: 2,
  barcode: null as unknown as string,
  hidden: false,
  ...over,
});

const recipe = (id: number, name: string, over: Partial<RecipeResponse> = {}): RecipeResponse => ({
  id,
  name,
  description: null,
  favorite: false,
  servings: 2,
  imageUpdatedAt: null,
  ingredients: [
    { foodId: 1, foodName: "x", quantityInGrams: 300, calories: 600, protein: 30 },
    { foodId: 2, foodName: "y", quantityInGrams: 100, calories: 224, protein: 10 },
  ],
  ...over,
});

const foods = [
  food(1, "Görög joghurt 2%"),
  food(2, "Natúr joghurt 3,5%"),
  food(3, "Joghurt 10%"),
  food(4, "Skyr natúr"),
  food(5, "Kefir"),
  food(6, "Barna rizs (főtt)"),
  food(7, "Gyümölcsjoghurt"),
  food(8, "Egyszeri gyors snack", { hidden: true }), // a one-off "enter macros" entry
];
const recipes = [recipe(10, "Joghurtos zabkása", { favorite: true }), recipe(11, "Csirkés rizstál")];
const items = buildSearchItems(foods, recipes);
const now = Date.now();
const DAY = 86_400_000;
const usage = (entries: Record<string, [daysAgo: number, count: number]>) =>
  new Map<string, ItemUsage>(Object.entries(entries).map(([k, [d, c]]) => [k, { lastUsedAt: now - d * DAY, useCount: c }]));
const names = (list: { name: string }[]) => list.map((i) => i.name);
const run = (query: string, filter: SearchFilter = "all", u = new Map<string, ItemUsage>()) =>
  names(searchItems({ items, query, filter, usage: u }));

describe("buildSearchItems", () => {
  it("includes foods and recipes, but never the hidden one-off foods", () => {
    expect(items).toHaveLength(7 + 2);
    expect(names(items)).not.toContain("Egyszeri gyors snack");
  });

  it("computes a recipe's kcal per serving and per 100 g of the dish", () => {
    const r = items.find((i) => i.kind === "recipe" && i.name === "Joghurtos zabkása");
    expect(r?.kind).toBe("recipe");
    if (r?.kind === "recipe") {
      expect(r.kcalPerServing).toBe(412); // (600 + 224) / 2
      expect(r.kcalPer100g).toBeCloseTo(206, 0); // 824 / 400 g
    }
  });
});

describe("searchItems — filters", () => {
  it("Foods and Recipes split by kind", () => {
    expect(run("", "foods")).toHaveLength(7);
    expect(run("", "recipes")).toEqual(["Csirkés rizstál", "Joghurtos zabkása"]);
  });

  it("Favourites are favourite recipes only", () => {
    expect(run("", "favorites")).toEqual(["Joghurtos zabkása"]);
  });

  it("Recent is what was logged lately, newest first", () => {
    const u = usage({ "food:5": [1, 1], "recipe:10": [0, 1], "food:2": [3, 4] });
    expect(run("", "recent", u)).toEqual(["Joghurtos zabkása", "Kefir", "Natúr joghurt 3,5%"]);
  });

  it("a filter and a query combine", () => {
    expect(run("joghurt", "foods")).not.toContain("Joghurtos zabkása");
    expect(run("joghurt", "recipes")).toEqual(["Joghurtos zabkása"]);
  });
});

describe("searchItems — ranking with a query", () => {
  it("names that start with the query come before names that merely contain it", () => {
    const out = run("joghurt");
    // "Joghurt 10%" and "Joghurtos zabkása" start with it; the rest contain it
    expect(out.slice(0, 2).sort()).toEqual(["Joghurt 10%", "Joghurtos zabkása"]);
    expect(out.slice(2)).toEqual(expect.arrayContaining(["Görög joghurt 2%", "Natúr joghurt 3,5%", "Gyümölcsjoghurt"]));
  });

  it("an exact match beats a longer prefix", () => {
    const list = [food(1, "Tej 1,5%"), food(2, "Tej")];
    const out = searchItems({ items: buildSearchItems(list, []), query: "tej", filter: "all", usage: new Map() });
    expect(names(out)).toEqual(["Tej", "Tej 1,5%"]);
  });

  it("among prefix matches, the recently logged one goes first", () => {
    const u = usage({ "recipe:10": [2, 1] });
    expect(run("joghurt", "all", u)[0]).toBe("Joghurtos zabkása");
  });

  it("among the rest, a recent one beats an older one, and a word-prefix beats a substring", () => {
    const u = usage({ "food:7": [1, 1] }); // "Gyümölcsjoghurt" is only a substring match, but recent
    const out = run("joghurt", "all", u);
    const rest = out.slice(2);
    expect(rest[0]).toBe("Gyümölcsjoghurt");
    // no usage: "Görög joghurt" / "Natúr joghurt" (word starts with the query) outrank "Gyümölcsjoghurt" (substring)
    const cold = run("joghurt").slice(2);
    expect(cold.indexOf("Gyümölcsjoghurt")).toBeGreaterThan(cold.indexOf("Görög joghurt 2%"));
    expect(cold.indexOf("Gyümölcsjoghurt")).toBeGreaterThan(cold.indexOf("Natúr joghurt 3,5%"));
  });

  it("ignores case and accents: 'rizs' and 'RÍZS' both find 'Barna rizs' and 'Csirkés rizstál'", () => {
    expect(run("rizs").sort()).toEqual(["Barna rizs (főtt)", "Csirkés rizstál"]);
    expect(run("RÍZS").sort()).toEqual(["Barna rizs (főtt)", "Csirkés rizstál"]);
    expect(run("gorog")).toEqual(["Görög joghurt 2%"]);
  });

  it("a query with no match is an empty list", () => {
    expect(run("pizza")).toEqual([]);
  });

  it("surrounding spaces in the query don't matter", () => {
    expect(run("  kefir ")).toEqual(["Kefir"]);
  });
});

describe("searchItems — without a query", () => {
  it("leads with recent, then frequent, then the rest alphabetically", () => {
    const u = usage({ "food:5": [0, 1], "food:2": [10, 6], "food:4": [30, 3] });
    const out = run("", "all", u);
    expect(out[0]).toBe("Kefir"); // the most recent
    expect(out.slice(0, 3).sort()).toEqual(["Kefir", "Natúr joghurt 3,5%", "Skyr natúr"]); // all three are recent (used at all)
    const rest = out.slice(3);
    expect(rest).toEqual([...rest].sort((a, b) => a.localeCompare(b)));
  });

  it("with no history at all it is just alphabetical", () => {
    const out = run("");
    expect(out).toEqual([...out].sort((a, b) => a.localeCompare(b)));
  });

  it("usageByKey merges food and recipe usage under their keys", () => {
    const m = usageByKey(
      new Map([[5, { lastUsedAt: 1, useCount: 2, lastGrams: 100 }]]),
      new Map([[10, { lastUsedAt: 2, useCount: 1 }]]),
    );
    expect(m.get("food:5")).toEqual({ lastUsedAt: 1, useCount: 2 });
    expect(m.get("recipe:10")).toEqual({ lastUsedAt: 2, useCount: 1 });
  });
});

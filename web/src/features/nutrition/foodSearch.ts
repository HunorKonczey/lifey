import { normalizeForSearch } from "@/lib/utils/search";
import type { FoodUsage } from "./usage";
import type { FoodResponse, RecipeResponse } from "./types";

/** One row of the add-food dialog's result list: a food or a recipe. */
export interface FoodItem {
  kind: "food";
  key: string;
  name: string;
  food: FoodResponse;
}

export interface RecipeItem {
  kind: "recipe";
  key: string;
  name: string;
  recipe: RecipeResponse;
  /** kcal of one serving (ingredients' total over `servings`). */
  kcalPerServing: number;
  /** kcal per 100 g of the whole dish — what the right-hand number of the row shows. */
  kcalPer100g: number;
}

export type SearchItem = FoodItem | RecipeItem;

export type SearchFilter = "all" | "foods" | "recipes" | "favorites" | "recent";
export const SEARCH_FILTERS: SearchFilter[] = ["all", "foods", "recipes", "favorites", "recent"];

/** Usage of a result row: when it was last logged and how often (90-day window, see `usage.ts`). */
export interface ItemUsage {
  lastUsedAt: number;
  useCount: number;
  /** Grams of the most recent log of a food — the quantity chip ("150 g"). Not set for recipes. */
  lastGrams?: number;
}

/** How many "recent" rows the empty state and the Recent filter show. */
export const RECENT_LIMIT = 12;

/** The searchable rows: the user's foods (not the hidden one-off "enter macros" ones) and recipes. */
export function buildSearchItems(foods: FoodResponse[], recipes: RecipeResponse[]): SearchItem[] {
  const foodItems: SearchItem[] = foods
    .filter((f) => !f.hidden)
    .map((food) => ({ kind: "food", key: `food:${food.id}`, name: food.name, food }));

  const recipeItems: SearchItem[] = recipes.map((recipe) => {
    const kcal = recipe.ingredients.reduce((s, i) => s + i.calories, 0);
    const grams = recipe.ingredients.reduce((s, i) => s + i.quantityInGrams, 0);
    return {
      kind: "recipe",
      key: `recipe:${recipe.id}`,
      name: recipe.name,
      recipe,
      kcalPerServing: kcal / Math.max(recipe.servings, 1),
      kcalPer100g: grams > 0 ? (kcal / grams) * 100 : 0,
    };
  });

  return [...foodItems, ...recipeItems];
}

/** Usage per result key from the food usage map and recipe usage (recipes are found in meals by name). */
export function usageByKey(
  foodUsage: Map<number, FoodUsage>,
  recipeUsage: Map<number, ItemUsage>,
): Map<string, ItemUsage> {
  const out = new Map<string, ItemUsage>();
  for (const [id, u] of foodUsage) out.set(`food:${id}`, { lastUsedAt: u.lastUsedAt, useCount: u.useCount, lastGrams: u.lastGrams });
  for (const [id, u] of recipeUsage) out.set(`recipe:${id}`, u);
  return out;
}

function matchesFilter(item: SearchItem, filter: SearchFilter, usage: Map<string, ItemUsage>): boolean {
  switch (filter) {
    case "all":
      return true;
    case "foods":
      return item.kind === "food";
    case "recipes":
      return item.kind === "recipe";
    case "favorites":
      return item.kind === "recipe" ? item.recipe.favorite : item.food.favorite === true;
    case "recent":
      return usage.has(item.key);
  }
}

const byRecency = (usage: Map<string, ItemUsage>) => (a: SearchItem, b: SearchItem) =>
  (usage.get(b.key)?.lastUsedAt ?? 0) - (usage.get(a.key)?.lastUsedAt ?? 0);

/**
 * The result list for a query and filter (W2.5). With a query, rows whose
 * name *starts with* it come first (an exact match before a longer prefix),
 * then — inside each group — recently logged rows, then a word that starts
 * with the query before a mere substring, then the newest use, then the
 * alphabet; matching ignores case and accents ("rizs" finds "Rízs"). Without
 * a query the list leads with what you logged lately, then what you log
 * often, then everything else alphabetically; the Recent filter is just
 * the lately-logged rows.
 */
export function searchItems({
  items,
  query,
  filter,
  usage,
}: {
  items: SearchItem[];
  query: string;
  filter: SearchFilter;
  usage: Map<string, ItemUsage>;
}): SearchItem[] {
  const pool = items.filter((i) => matchesFilter(i, filter, usage));
  const recency = byRecency(usage);
  const nq = normalizeForSearch(query.trim());

  if (nq === "") {
    const recents = [...pool].filter((i) => usage.has(i.key)).sort(recency);
    if (filter === "recent") return recents.slice(0, RECENT_LIMIT);

    const promoted = new Set(recents.slice(0, RECENT_LIMIT).map((i) => i.key));
    const frequent = pool
      .filter((i) => !promoted.has(i.key) && (usage.get(i.key)?.useCount ?? 0) >= 2)
      .sort((a, b) => (usage.get(b.key)!.useCount - usage.get(a.key)!.useCount) || recency(a, b));
    frequent.forEach((i) => promoted.add(i.key));

    const rest = pool.filter((i) => !promoted.has(i.key)).sort((a, b) => a.name.localeCompare(b.name));
    return [...recents.slice(0, RECENT_LIMIT), ...frequent, ...rest];
  }

  type Scored = { item: SearchItem; exact: boolean; prefix: boolean; wordPrefix: boolean; recent: boolean };
  const scored: Scored[] = [];
  for (const item of pool) {
    const name = normalizeForSearch(item.name);
    if (!name.includes(nq)) continue;
    scored.push({
      item,
      exact: name === nq,
      prefix: name.startsWith(nq),
      wordPrefix: name.split(/[\s\-(,]+/).some((w) => w.startsWith(nq)),
      recent: usage.has(item.key),
    });
  }

  scored.sort(
    (a, b) =>
      Number(b.prefix) - Number(a.prefix) ||
      Number(b.exact) - Number(a.exact) ||
      Number(b.recent) - Number(a.recent) ||
      Number(b.wordPrefix) - Number(a.wordPrefix) ||
      recency(a.item, b.item) ||
      a.item.name.localeCompare(b.item.name),
  );
  return scored.map((s) => s.item);
}

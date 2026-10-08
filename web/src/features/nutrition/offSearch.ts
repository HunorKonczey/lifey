import { isHuLocale } from "@/lib/format/lifeyFormat";
import type { SearchItem } from "./foodSearch";
import type { Macros } from "./recipeMacros";
import type { OffSearchItem, OffSearchLang, OffSearchResponse } from "./types";

/**
 * The rules of the add-food dialog's "Search OpenFoodFacts too" option (docs/84), kept pure so they can be
 * tested: what is typed → the text that is sent, whether a request is made at all, the language, and the
 * mapping of a result onto a result-list row. The hook that runs them is `useOffSearch`.
 */

/** Fewer letters/digits than this and the backend answers 400 (`FoodController.MIN_OFF_SEARCH_LENGTH`). */
export const OFF_SEARCH_MIN_LENGTH = 3;
/** Typing a word is one request, not one per letter — OFF allows few searches (docs/84 D7). */
export const OFF_SEARCH_DEBOUNCE_MS = 400;
/** The backend caches for 10 minutes too; the same search again in that time is not asked twice. */
export const OFF_SEARCH_STALE_MS = 10 * 60_000;

const DISALLOWED = /[^\p{L}\p{N}'’\- ]/gu;
// A hyphen that is not between two letters/digits means "NOT" to the search syntax, or is noise.
const LOOSE_HYPHEN = /(?<![\p{L}\p{N}])-|-(?![\p{L}\p{N}])/gu;

/**
 * What is sent to the backend: the same cleaning the backend does (`OffSearchQuery.sanitize`) — lower case,
 * accents kept, only letters, digits, spaces, apostrophes and hyphens inside a word. Doing it here as well
 * makes "Tej" and "tej" one cache entry and keeps the 3-character rule honest on both sides.
 */
export function sanitizeOffQuery(raw: string): string {
  return raw
    .toLowerCase()
    .replace(DISALLOWED, " ")
    .replace(LOOSE_HYPHEN, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** Enough to search: at least 3 letters or digits in the cleaned text (spaces and hyphens do not count). */
export function isOffSearchable(text: string): boolean {
  return [...sanitizeOffQuery(text)].filter((c) => /[\p{L}\p{N}]/u.test(c)).length >= OFF_SEARCH_MIN_LENGTH;
}

/** A request is made only with the option ticked and both what is typed now and what settled after the debounce searchable. */
export function offSearchEnabled(checked: boolean, typed: string, settled: string): boolean {
  return checked && isOffSearchable(typed) && isOffSearchable(settled);
}

/** The backend searches `hu` or `en`; the UI language decides (it treats anything else as `en` too). */
export function offSearchLang(locale: string): OffSearchLang {
  return isHuLocale(locale) ? "hu" : "en";
}

/** An OpenFoodFacts result as a row of the add-food result list (docs/84 §3.1). */
export interface OffItem {
  kind: "off";
  key: string;
  name: string;
  off: OffSearchItem;
}

/**
 * The row for a result. Deliberately **not** in `SearchItem`: that union is what `searchItems()` ranks and
 * filters (the user's own foods and recipes), and OpenFoodFacts rows must never be ranked into it (docs/84 §3.1).
 */
export function offItemToSearchItem(item: OffSearchItem): OffItem {
  return { kind: "off", key: `off:${item.barcode}`, name: item.name, off: item };
}

/** Anything the dialog can highlight and preview: an own food or recipe, or an OpenFoodFacts result. */
export type ListItem = SearchItem | OffItem;

/** The barcodes of the user's own foods in the add-food list. */
export function ownedBarcodes(items: ReadonlyArray<SearchItem>): Set<string> {
  const owned = new Set<string>();
  for (const item of items) {
    if (item.kind === "food" && item.food.barcode) owned.add(item.food.barcode);
  }
  return owned;
}

/**
 * The OpenFoodFacts rows without the products the user already owns. The server leaves an owned barcode out of a *new*
 * search, but an answer cached for ten minutes still lists a product that was saved a moment ago (LIF-134) — it would sit
 * in the OpenFoodFacts group right under the same food in "Own". Filtering here costs no request, and a deleted food
 * frees its product again at once.
 */
export function withoutOwnedProducts(items: OffItem[], owned: ReadonlySet<string>): OffItem[] {
  return owned.size === 0 ? items : items.filter((item) => !owned.has(item.off.barcode));
}

/** A product's macros for `grams`; carbs and fat that OpenFoodFacts lacks count as 0, as the barcode flow does. */
export function offPortion(item: OffSearchItem, grams: number): Macros {
  const k = grams / 100;
  return {
    calories: item.caloriesPer100g * k,
    protein: item.proteinPer100g * k,
    carbs: (item.carbsPer100g ?? 0) * k,
    fat: (item.fatPer100g ?? 0) * k,
  };
}

/** The one line to show under the OpenFoodFacts rows, if any (docs/84 §3.1). A failed request reads as unavailable. */
export type OffNote = "fellBack" | "unavailable" | "rateLimited";

export function offSearchNote(response: OffSearchResponse | undefined, failed: boolean): OffNote | null {
  if (failed) return "unavailable";
  if (!response) return null;
  if (response.status === "UNAVAILABLE") return "unavailable";
  if (response.status === "RATE_LIMITED") return "rateLimited";
  return response.fellBackToEnglish ? "fellBack" : null;
}

/** Per-device memory of the checkbox (docs/84 D10): off until the user ticks it, then remembered. */
export const OFF_SEARCH_PREF_KEY = "lifey.addFood.offSearch";

type KeyValueStorage = Pick<Storage, "getItem" | "setItem">;

function defaultStorage(): KeyValueStorage | undefined {
  try {
    return typeof localStorage === "undefined" ? undefined : localStorage;
  } catch {
    return undefined; // blocked site data: the accessor itself can throw
  }
}

/** Never throws: private windows and blocked storage just mean "off". */
export function readOffSearchPreference(storage: KeyValueStorage | undefined = defaultStorage()): boolean {
  try {
    return storage?.getItem(OFF_SEARCH_PREF_KEY) === "1";
  } catch {
    return false;
  }
}

export function writeOffSearchPreference(on: boolean, storage: KeyValueStorage | undefined = defaultStorage()): void {
  try {
    storage?.setItem(OFF_SEARCH_PREF_KEY, on ? "1" : "0");
  } catch {
    // not remembered; the checkbox still works for this session
  }
}

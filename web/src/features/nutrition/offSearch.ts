import { isHuLocale } from "@/lib/format/lifeyFormat";
import type { OffSearchItem, OffSearchLang } from "./types";

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
 * The row for a result. Not part of the `SearchItem` union yet: adding it there is the UI step (it changes
 * every place that tells a food from a recipe), and until then nothing renders it.
 */
export function offItemToSearchItem(item: OffSearchItem): OffItem {
  return { kind: "off", key: `off:${item.barcode}`, name: item.name, off: item };
}

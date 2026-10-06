import { useEffect, useSyncExternalStore } from "react";
import { isOffSearchable, offItemToSearchItem, offSearchEnabled, sanitizeOffQuery } from "@/features/nutrition/offSearch";
import type { OffSearchItem, OffSearchResponse } from "@/features/nutrition/types";
import type { UseOffSearchResult } from "@/features/nutrition/useOffSearch";
import { useDebouncedValue } from "@/lib/hooks/useDebouncedValue";
import { normalizeForSearch } from "@/lib/utils/search";

/**
 * The OpenFoodFacts option on fixture data (docs/84), shared by the gallery sections that have it — the add-food dialog and
 * the food editor. The gallery has no backend, so the option's hook is replaced by canned answers; the request counter is
 * global, so a test can show that an unticked box makes none.
 */

const off = (barcode: string, name: string, brand: string | null, kcal: number, protein: number, carbs: number | null, fat: number | null): OffSearchItem => ({
  barcode, name, brand, caloriesPer100g: kcal, proteinPer100g: protein, carbsPer100g: carbs, fatPer100g: fat,
});
const OFF_FIXTURE = [
  off("4056489827702", "Csirkemell", "Pikok", 110, 14, 2.4, 4.9),
  off("5999033874557", "Csirkemell sonka", "S-Budget", 109, 15, 2, 4.5),
  off("5998202960657", "Rántott csirkemell", "Nádudvari", 196, 10.6, null, null),
  off("5997000000001", "Túró Rudi", null, 400, 11, 33, 25),
  off("5711953000013", "Skyr vaníliás", "Arla", 66, 11, 5, 0.2),
];
const OFF_ENGLISH_FIXTURE = [off("0722252601025", "Pumpkin puree", "Libby's", 34, 1.1, 8, 0.1)];

/** Magic words give the e2e tests every state: slowpoke → still loading, boom → the request failed, unavail / limited → the statuses, pumpkin → the English fallback, nothing → empty. */
function offAnswer(text: string): OffSearchResponse {
  const base = { language: "hu" as const, fellBackToEnglish: false, items: [] as OffSearchItem[] };
  if (text === "unavail") return { ...base, status: "UNAVAILABLE" };
  if (text === "limited") return { ...base, status: "RATE_LIMITED" };
  if (text === "pumpkin") return { status: "OK", language: "en", fellBackToEnglish: true, items: OFF_ENGLISH_FIXTURE };
  const q = normalizeForSearch(text);
  return { ...base, status: "OK", items: OFF_FIXTURE.filter((i) => normalizeForSearch(i.name).includes(q)) };
}

// Every request the fixture "would make", so a test can show that an unticked box makes none.
const requests: string[] = [];
const listeners = new Set<() => void>();
const subscribeRequests = (l: () => void) => (listeners.add(l), () => void listeners.delete(l));
const requestCount = () => requests.length;

/** How many requests the fixture has "made" so far. */
export function useFixtureOffRequestCount(): number {
  return useSyncExternalStore(subscribeRequests, requestCount, requestCount);
}
function recordRequest(text: string) {
  requests.push(text);
  listeners.forEach((l) => l());
}

const IDLE: UseOffSearchResult = { active: false, pending: false, items: [], response: undefined, failed: false };

export function useFixtureOff({ query, checked }: { query: string; checked: boolean }): UseOffSearchResult {
  const text = sanitizeOffQuery(query);
  // The same shape as the real hook: debounced, so typing a word is one "request".
  const settled = useDebouncedValue(text, 150);
  const active = offSearchEnabled(checked, text, settled);
  useEffect(() => {
    if (active) recordRequest(settled);
  }, [active, settled]);
  const settling = checked && isOffSearchable(text) && text !== settled;
  if (!active) return { ...IDLE, pending: settling };
  if (settled === "slowpoke") return { ...IDLE, active: true, pending: true };
  if (settled === "boom") return { ...IDLE, active: true, pending: settling, failed: true };
  const response = offAnswer(settled);
  return { active: true, pending: settling, items: response.items.map(offItemToSearchItem), response, failed: false };
}

export function readGalleryOffPreference(): boolean {
  try {
    return window.localStorage.getItem("lifey.addFood.offSearch") === "1";
  } catch {
    return false;
  }
}

export function writeGalleryOffPreference(on: boolean): void {
  try {
    window.localStorage.setItem("lifey.addFood.offSearch", on ? "1" : "0");
  } catch {
    /* the gallery just does not remember */
  }
}
